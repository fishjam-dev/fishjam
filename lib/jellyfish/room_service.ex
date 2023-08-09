defmodule Jellyfish.RoomService do
  @moduledoc """
  Module responsible for managing rooms.
  """

  use GenServer

  require Logger

  alias Jellyfish.Event
  alias Jellyfish.Room

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec find_room(Room.id()) :: {:ok, pid()} | {:error, :room_not_found}
  def find_room(room_id) do
    case Registry.lookup(Jellyfish.RoomRegistry, room_id) do
      [{room_pid, nil}] ->
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
    Jellyfish.RoomRegistry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.map(&Room.get_state(&1))
    |> Enum.reject(&(&1 == nil))
  end

  @spec create_room(Room.max_peers(), String.t()) ::
          {:ok, Room.t(), String.t()} | {:error, :invalid_max_peers | :invalid_video_codec}
  def create_room(max_peers, video_codec) do
    {node_resources, failed_nodes} =
      :rpc.multicall(Jellyfish.RoomService, :get_resource_usage, [])

    if Enum.count(failed_nodes) > 0 do
      Logger.warn(
        "Couldn't get resource usage of the following nodes. Reason: nodes don't exist. Nodes: #{inspect(failed_nodes)}"
      )
    end

    {min_node, _room_size} =
      Enum.min_by(node_resources, fn {_node_name, room_num} -> room_num end)

    if Enum.count(node_resources) > 1 do
      Logger.info("Node with least used resources is #{inspect(min_node)}")
      GenServer.call({__MODULE__, min_node}, {:create_room, max_peers, video_codec})
    else
      GenServer.call(__MODULE__, {:create_room, max_peers, video_codec})
    end
  end

  @spec delete_room(Room.id()) :: :ok | {:error, :room_not_found}
  def delete_room(room_id) do
    GenServer.call(__MODULE__, {:delete_room, room_id})
  end

  @spec get_resource_usage() :: {Node.t(), integer()}
  def get_resource_usage() do
    list_rooms() |> Enum.count() |> then(&{Node.self(), &1})
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
  def handle_call({:create_room, max_peers, video_codec}, _from, state) do
    with :ok <- validate_max_peers(max_peers),
         {:ok, video_codec} <- codec_to_atom(video_codec) do
      {:ok, room_pid, room_id} = Room.start(max_peers, video_codec)

      room = Room.get_state(room_id)
      Process.monitor(room_pid)

      state = put_in(state, [:rooms, room_pid], room_id)

      Logger.info("Created room #{inspect(room.id)}")

      Event.broadcast(:server_notification, {:room_created, room_id})

      {:reply, {:ok, room, Application.fetch_env!(:jellyfish, :address)}, state}
    else
      {:error, :max_peers} ->
        {:reply, {:error, :invalid_max_peers}, state}

      {:error, :video_codec} ->
        {:reply, {:error, :invalid_video_codec}, state}
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
  def handle_info({:resources, _node_name, _resources}, state) do
    {:noreply, state}
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

    Logger.warn("Process #{room_id} is down with reason: #{reason}")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, room_id, :room_crashed)
    Event.broadcast(:server_notification, {:room_crashed, room_id})

    {:noreply, state}
  end

  defp remove_room(room_id) do
    room = {:via, Registry, {Jellyfish.RoomRegistry, room_id}}

    try do
      :ok = GenServer.stop(room, :normal)
      Logger.info("Deleted room #{inspect(room_id)}")

      Event.broadcast(:server_notification, {:room_deleted, room_id})
    catch
      :exit, {:noproc, {GenServer, :stop, [^room, :normal, :infinity]}} ->
        Logger.warn("Room process with id #{inspect(room_id)} doesn't exist")
    end
  end

  defp validate_max_peers(nil), do: :ok
  defp validate_max_peers(max_peers) when is_integer(max_peers) and max_peers >= 0, do: :ok
  defp validate_max_peers(_max_peers), do: {:error, :max_peers}

  defp codec_to_atom("h264"), do: {:ok, :h264}
  defp codec_to_atom("vp8"), do: {:ok, :vp8}
  defp codec_to_atom(nil), do: {:ok, nil}
  defp codec_to_atom(_codec), do: {:error, :video_codec}
end
