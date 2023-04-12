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
    {:ok, %{rooms: %{}}}
  end

  @impl true
  def handle_call({:create_room, max_peers}, _from, state)
      when is_nil(max_peers) or (is_integer(max_peers) and max_peers >= 0) do
    {:ok, room_pid, room_id} = Room.start(max_peers)
    room = Room.get_state(room_id)
    Process.monitor(room_pid)

    state = put_in(state, [:rooms, room_pid], room_id)

    Logger.info("Created room #{inspect(room.id)}")
    {:reply, {:ok, room}, state}
  end

  @impl true
  def handle_call({:create_room, _max_peers}, _from, state),
    do: {:reply, {:error, :bad_arg}, state}

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

    Logger.warn("Process #{room_id} is down with reason: #{reason}")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, room_id, :room_crashed)
    Phoenix.PubSub.broadcast(Jellyfish.PubSub, "server", {:room_crashed, room_id})

    {:noreply, state}
  end

  defp remove_room(room_id) do
    room = {:via, Registry, {Jellyfish.RoomRegistry, room_id}}

    try do
      :ok = GenServer.stop(room, :normal)
      Logger.info("Deleted room #{inspect(room_id)}")
    catch
      :exit, {:noproc, {GenServer, :stop, [^room, :normal, :infinity]}} ->
        Logger.warn("Room process with id #{inspect(room_id)} doesn't exist")
    end
  end
end
