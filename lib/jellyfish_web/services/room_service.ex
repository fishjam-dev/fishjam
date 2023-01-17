defmodule JellyfishWeb.RoomService do
  use GenServer
  alias Jellyfish.Room

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_) do
    :ets.new(:rooms, [:protected, :set, :named_table])
    {:ok, %{rooms: %{}}}
  end

  @impl true
  def handle_call({:create_room, max_peers}, _from, state) do
    {:ok, room_pid} = GenServer.start_link(Room, max_peers)
    room = GenServer.call(room_pid, :state)

    :ets.insert(:rooms, {room.id, room_pid})

    {:reply, room, %{state | rooms: Map.put(state.rooms, room.id, room_pid)}}
  end

  @impl true
  def handle_call(:list_rooms, _from, state) do
    rooms =
      Enum.map(state.rooms, fn {_room_id, room_pid} ->
        GenServer.call(room_pid, :state)
      end)

    {:reply, rooms, state}
  end

  @impl true
  def handle_call({:delete_room, room_id}, _from, state) when is_map_key(state.rooms, room_id) do
    state = Map.delete(state, room_id)
    :ets.delete(:rooms, room_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_room, _room_id}, _from, state) do
    {:reply, :not_found, state}
  end
end
