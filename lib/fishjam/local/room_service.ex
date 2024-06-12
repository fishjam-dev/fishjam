defmodule Fishjam.Local.RoomService do
  @moduledoc """
  Module responsible for managing rooms on this Fishjam instance.
  """

  @behaviour Fishjam.RoomService

  use GenServer

  require Logger

  alias Fishjam.Event
  alias Fishjam.Local.Room
  alias Fishjam.Room.ID
  alias Fishjam.WebhookNotifier

  @metric_interval_in_seconds Application.compile_env!(:fishjam, :room_metrics_scrape_interval)
  @metric_interval_in_milliseconds @metric_interval_in_seconds * 1_000

  ## NON-ROUTABLE FUNCTIONS

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec get_resource_usage() :: %{
          node: Node.t(),
          forwarded_tracks_number: integer(),
          rooms_number: integer()
        }
  def get_resource_usage() do
    room_ids = get_rooms_ids()

    room_ids
    |> Enum.map(fn room_id ->
      Task.Supervisor.async_nolink(Fishjam.TaskSupervisor, fn ->
        Room.get_num_forwarded_tracks(room_id)
      end)
    end)
    |> Task.yield_many()
    |> Enum.map(fn {task, res} ->
      res || Task.shutdown(task, :brutal_kill)
    end)
    |> Enum.filter(fn
      {:ok, _res} -> true
      _other -> false
    end)
    |> Enum.map(fn {:ok, res} -> res end)
    |> then(
      &%{node: Node.self(), forwarded_tracks_number: Enum.sum(&1), rooms_number: Enum.count(&1)}
    )
  end

  ## CLUSTER-ROUTABLE FUNCTIONS

  @impl Fishjam.RoomService
  def find_room(room_id) do
    case Registry.lookup(Fishjam.RoomRegistry, room_id) do
      [{room_pid, _value}] ->
        {:ok, room_pid}

      _not_found ->
        {:error, :room_not_found}
    end
  end

  @impl Fishjam.RoomService
  def get_room(room_id) do
    room = Room.get_state(room_id)

    if is_nil(room) do
      {:error, :room_not_found}
    else
      {:ok, room}
    end
  end

  @impl Fishjam.RoomService
  def list_rooms() do
    get_rooms_ids()
    |> Enum.map(&Room.get_state(&1))
    |> Enum.reject(&(&1 == nil))
  end

  @impl Fishjam.RoomService
  def create_room(config) do
    GenServer.call(__MODULE__, {:create_room, config})
  end

  @impl Fishjam.RoomService
  def delete_room(room_id) do
    GenServer.call(__MODULE__, {:delete_room, room_id})
  end

  ## GENSERVER CALLBACKS

  @impl true
  def init(_opts) do
    {:ok, %{rooms: %{}}, {:continue, nil}}
  end

  @impl true
  def handle_continue(_continue_arg, state) do
    Process.send_after(self(), :rooms_metrics, @metric_interval_in_milliseconds)
    :ok = Phoenix.PubSub.subscribe(Fishjam.PubSub, "fishjams")
    {:noreply, state}
  end

  @impl true
  def handle_call({:create_room, config}, _from, state) do
    Logger.debug("Creating a new room")

    # Re-generate the room ID to ensure it has the correct node name part
    {:ok, room_id} = ID.generate(config.room_id)
    config = %{config | room_id: room_id}

    with {:ok, room_pid, room_id} <- Room.start(config) do
      Logger.debug("Room created successfully")
      room = Room.get_state(room_id)
      Process.monitor(room_pid)

      state = put_in(state, [:rooms, room_pid], room_id)

      WebhookNotifier.add_webhook(room_id, config.webhook_url)

      Logger.info("Created room #{inspect(room.id)}")

      Event.broadcast_server_notification({:room_created, room_id})

      {:reply, {:ok, room, Fishjam.address()}, state}
    else
      {:error, :room_already_exists} = error ->
        Logger.warning("Room creation failed, because it already exists")

        {:reply, error, state}

      reason ->
        Logger.warning("Room creation failed with reason: #{inspect(reason)}")
        {:reply, {:error, :room_doesnt_start}, state}
    end
  end

  @impl true
  def handle_call({:delete_room, room_id}, _from, state) do
    response =
      case find_room(room_id) do
        {:ok, _room_pid} ->
          remove_room(room_id)
          :ok

        {:error, _} ->
          {:error, :room_not_found}
      end

    {:reply, response, state}
  end

  @impl true
  def handle_info(:rooms_metrics, state) do
    rooms = list_rooms()

    :telemetry.execute(
      [:fishjam],
      %{
        rooms: Enum.count(rooms)
      }
    )

    for room <- rooms do
      peer_count = room.peers |> Enum.count()

      :telemetry.execute(
        [:fishjam, :room],
        %{
          peers: peer_count,
          peer_time: peer_count * @metric_interval_in_seconds,
          duration: @metric_interval_in_seconds
        },
        %{room_id: room.id}
      )
    end

    Process.send_after(self(), :rooms_metrics, @metric_interval_in_milliseconds)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, :normal}, state) do
    {room_id, state} = pop_in(state, [:rooms, pid])

    Logger.debug("Room #{inspect(room_id)} is down with reason: normal")

    Phoenix.PubSub.broadcast(Fishjam.PubSub, room_id, :room_stopped)
    Event.broadcast_server_notification({:room_deleted, room_id})
    clear_room_metrics(room_id)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {room_id, state} = pop_in(state, [:rooms, pid])

    Logger.warning("Process #{room_id} is down with reason: #{inspect(reason)}")

    Phoenix.PubSub.broadcast(Fishjam.PubSub, room_id, :room_crashed)
    Event.broadcast_server_notification({:room_crashed, room_id})
    clear_room_metrics(room_id)

    {:noreply, state}
  end

  defp clear_room_metrics(room_id) do
    :telemetry.execute([:fishjam, :room], %{peers: 0}, %{room_id: room_id})
  end

  defp get_rooms_ids() do
    Fishjam.RoomRegistry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  defp remove_room(room_id) do
    room = Room.registry_id(room_id)

    try do
      :ok = GenServer.stop(room, :normal)
      Logger.info("Deleted room #{inspect(room_id)}")
    catch
      :exit, {:noproc, {GenServer, :stop, [^room, :normal, :infinity]}} ->
        Logger.warning("Room process with id #{inspect(room_id)} doesn't exist")
    end
  end
end
