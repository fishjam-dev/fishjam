defmodule Jellyfish.RoomService do
  @moduledoc """
  Module responsible for managing rooms.
  """

  use GenServer

  require Logger

  alias Jellyfish.{Event, Room, WebhookNotifier}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec find_room(Room.id()) :: {:ok, pid()} | {:error, :room_not_found}
  def find_room(room_id) do
    case Registry.lookup(Jellyfish.RoomRegistry, room_id) do
      [{room_pid, _value}] ->
        {:ok, room_pid}

      _not_found ->
        {:error, :room_not_found}
    end
  end

  @spec find_room!(Room.id()) :: pid() | no_return()
  def find_room!(room_id) do
    case find_room(room_id) do
      {:ok, pid} ->
        pid

      _not_found ->
        raise "Room with id #{room_id} doesn't exist"
    end
  end

  @spec get_room(Room.id()) :: {:ok, Room.t()} | {:error, :room_not_found}
  def get_room(room_id) do
    room = Room.get_state(room_id)

    if is_nil(room) do
      {:error, :room_not_found}
    else
      {:ok, room}
    end
  end

  @spec list_rooms() :: [Room.t()]
  def list_rooms() do
    get_rooms_ids()
    |> Enum.map(&Room.get_state(&1))
    |> Enum.reject(&(&1 == nil))
  end

  @spec create_room(Room.Config.max_peers(), String.t(), String.t()) ::
          {:ok, Room.t(), String.t()} | {:error, :invalid_max_peers | :invalid_video_codec}
  def create_room(max_peers, video_codec, webhook_url) do
    {node_resources, failed_nodes} =
      :rpc.multicall(Jellyfish.RoomService, :get_resource_usage, [])

    if Enum.count(failed_nodes) > 0 do
      Logger.warning(
        "Couldn't get resource usage of the following nodes. Reason: nodes don't exist. Nodes: #{inspect(failed_nodes)}"
      )
    end

    {failed_rpcs, node_resources} =
      Enum.split_with(node_resources, fn
        {:badrpc, _info} -> true
        _other -> false
      end)

    unless Enum.empty?(failed_rpcs) do
      Logger.warning("These RPC calls fail: #{inspect(failed_rpcs)}")
    end

    min_node = find_best_node(node_resources)

    if Enum.count(node_resources) > 1 do
      Logger.info("Node with least used resources is #{inspect(min_node)}")
      GenServer.call({__MODULE__, min_node}, {:create_room, max_peers, video_codec, webhook_url})
    else
      GenServer.call(__MODULE__, {:create_room, max_peers, video_codec, webhook_url})
    end
  end

  @spec delete_room(Room.id()) :: :ok | {:error, :room_not_found}
  def delete_room(room_id) do
    GenServer.call(__MODULE__, {:delete_room, room_id})
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
      Task.Supervisor.async_nolink(Jellyfish.TaskSupervisor, fn ->
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

  @impl true
  def init(_opts) do
    {:ok, %{rooms: %{}}, {:continue, nil}}
  end

  @impl true
  def handle_continue(_continue_arg, state) do
    :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, "jellyfishes")
    {:noreply, state}
  end

  @impl true
  def handle_call({:create_room, max_peers, video_codec, webhook_url}, _from, state) do
    with {:ok, config} <- Room.Config.new(max_peers, video_codec, webhook_url) do
      {:ok, room_pid, room_id} = Room.start(config)

      room = Room.get_state(room_id)
      Process.monitor(room_pid)

      state = put_in(state, [:rooms, room_pid], room_id)

      WebhookNotifier.add_webhook(room_id, webhook_url)

      Logger.info("Created room #{inspect(room.id)}")

      Event.broadcast_server_notification({:room_created, room_id})

      {:reply, {:ok, room, Application.fetch_env!(:jellyfish, :address)}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
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
  def handle_info({:DOWN, _ref, :process, pid, :normal}, state) do
    {room_id, state} = pop_in(state, [:rooms, pid])

    Logger.debug("Room #{room_id} is down with reason: normal")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, room_id, :room_stopped)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {room_id, state} = pop_in(state, [:rooms, pid])

    Logger.warning("Process #{room_id} is down with reason: #{reason}")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, room_id, :room_crashed)
    Event.broadcast_server_notification({:room_crashed, room_id})

    {:noreply, state}
  end

  defp find_best_node(node_resources) do
    %{node: min_node} =
      Enum.min(
        node_resources,
        fn
          %{forwarded_tracks_number: forwarded_tracks, rooms_number: rooms_num1},
          %{forwarded_tracks_number: forwarded_tracks, rooms_number: rooms_num2} ->
            rooms_num1 < rooms_num2

          %{forwarded_tracks_number: forwarded_tracks1},
          %{forwarded_tracks_number: forwarded_tracks2} ->
            forwarded_tracks1 < forwarded_tracks2
        end
      )

    min_node
  end

  defp get_rooms_ids() do
    Jellyfish.RoomRegistry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  defp remove_room(room_id) do
    room = Room.registry_id(room_id)

    try do
      :ok = GenServer.stop(room, :normal)
      Logger.info("Deleted room #{inspect(room_id)}")

      Event.broadcast_server_notification({:room_deleted, room_id})
    catch
      :exit, {:noproc, {GenServer, :stop, [^room, :normal, :infinity]}} ->
        Logger.warning("Room process with id #{inspect(room_id)} doesn't exist")
    end
  end
end
