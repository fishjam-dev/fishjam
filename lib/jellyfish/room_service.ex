defmodule Jellyfish.RoomService do
  @moduledoc """
  Module responsible for managing rooms.
  """

  use GenServer

  require Logger

  alias Jellyfish.Room

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec find_room(Room.id()) :: {:ok, pid()} | {:error, :room_not_found}
  def find_room(room_id) do
    case :ets.lookup(:rooms, room_id) do
      [{_room_id, room_pid} | _] -> {:ok, room_pid}
      _not_found -> {:error, :room_not_found}
    end
  end

  @spec list_rooms() :: [Room.t()]
  def list_rooms() do
    :rooms
    |> :ets.tab2list()
    |> Enum.map(fn {_id, room_pid} -> Room.get_state(room_pid) end)
  end

  @spec create_room(Room.max_peers()) :: {:ok, Room.t()} | {:error, :bad_arg}
  def create_room(max_peers) do
    GenServer.call(__MODULE__, {:create_room, max_peers})
  end

  @spec delete_room(Room.id()) :: :ok | {:error, :room_not_found}
  def delete_room(room_id) do
    GenServer.call(__MODULE__, {:delete_room, room_id})
  end

  @impl true
  def init(_opts) do
    Logger.info("Start #{__MODULE__}")
    :ets.new(:rooms, [:protected, :set, :named_table])
    {:ok, %{rooms: %{}}}
  end

  @impl true
  def handle_call({:create_room, max_peers}, _from, state)
      when is_nil(max_peers) or (is_integer(max_peers) and max_peers >= 0) do
    # {:ok, room_pid} = DynamicSupervisor.start_child(RoomSupervisor, {Room, max_peers})
    {:ok, room_pid} = Room.start(max_peers)
    Process.monitor(room_pid)
    room = Room.get_state(room_pid)

    Logger.info("Created room #{inspect(room.id)}")

    :ets.insert(:rooms, {room.id, room_pid})

    {:reply, {:ok, room}, %{state | rooms: Map.put(state.rooms, room.id, room_pid)}}
  end

  @impl true
  def handle_call({:create_room, _max_peers}, _from, state),
    do: {:reply, {:error, :bad_arg}, state}

  @impl true
  def handle_call({:delete_room, room_id}, _from, state) when is_map_key(state.rooms, room_id) do
    state = remove_room(state, room_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_room, _room_id}, _from, state) do
    {:reply, {:error, :room_not_found}, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.warn("Process (#{inspect(ref)}, #{inspect(pid)}) is down with reason: #{reason}")
    room_id = find_room_id_by_pid(pid)

    state =
      if room_id == nil do
        Logger.warn("There is no such process with pid #{inspect(pid)}")
        state
      else
        Phoenix.PubSub.broadcast!(Jellyfish.PubSub, room_id, :room_crashed)
        remove_room(state, room_id)
      end

    {:noreply, state}
  end

  defp find_room_id_by_pid(room_pid) do
    :rooms
    |> :ets.tab2list()
    |> Enum.find(fn
      {_id, ^room_pid} -> true
      _other -> false
    end)
    |> case do
      {id, _pid} -> id
      nil -> nil
    end
  end

  defp remove_room(state, room_id) when is_map_key(state.rooms, room_id) do
    state = %{state | rooms: Map.delete(state.rooms, room_id)}
    :ets.delete(:rooms, room_id)
    Logger.info("Deleted room #{inspect(room_id)}")
    state
  end

  defp remove_room(_state, room_id) do
    Logger.error("Room with room_id #{room_id} doesn't exist")
    raise "Room with room_id #{room_id} doesn't exist"
  end
end
