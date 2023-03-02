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
    :ets.new(:rooms, [:protected, :set, :named_table])
    {:ok, %{rooms: %{}}}
  end

  @impl true
  def handle_call({:create_room, max_peers}, _from, state)
      when is_nil(max_peers) or is_number(max_peers) do
    {:ok, room_pid} = Room.start_link(max_peers)
    room = Room.get_state(room_pid)

    Logger.info("Created room #{inspect(room.id)}")

    :ets.insert(:rooms, {room.id, room_pid})

    {:reply, {:ok, room}, %{state | rooms: Map.put(state.rooms, room.id, room_pid)}}
  end

  @impl true
  def handle_call({:create_room, _max_peers}, _from, state),
    do: {:reply, {:error, :bad_arg}, state}

  @impl true
  def handle_call(:list_rooms, _from, state) do
    rooms =
      Enum.map(state.rooms, fn {_room_id, room_pid} ->
        Room.get_state(room_pid)
      end)

    {:reply, rooms, state}
  end

  @impl true
  def handle_call({:delete_room, room_id}, _from, state) when is_map_key(state.rooms, room_id) do
    state = Map.delete(state, room_id)
    :ets.delete(:rooms, room_id)

    Logger.info("Deleted room #{inspect(room_id)}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_room, _room_id}, _from, state) do
    {:reply, {:error, :room_not_found}, state}
  end
end
