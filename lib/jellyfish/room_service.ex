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
      [{room_pid, ^room_id}] ->
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
    with {:ok, room_pid} <- find_room(room_id),
         room when not is_nil(room) <- Room.get_state(room_pid) do
      {:ok, room}
    else
      _error_or_nil -> {:error, :room_not_found}
    end
  end

  @spec list_rooms() :: [Room.t()]
  def list_rooms() do
    Jellyfish.RoomRegistry
    |> Registry.select([{{:_, :"$1", :_}, [], [:"$1"]}])
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
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_room, max_peers}, _from, state)
      when is_nil(max_peers) or (is_integer(max_peers) and max_peers >= 0) do
    {:ok, room_pid} = Room.start(max_peers)
    room = Room.get_state(room_pid)
    Process.monitor(room_pid)

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
        {:ok, _pid} ->
          remove_room(room_id)
          :ok

        {:error, _} ->
          {:error, :room_not_found}
      end

    {:reply, response, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, :normal}, state) do
    Logger.debug("Process (#{inspect(ref)}, #{inspect(pid)}) is down with reason: normal")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, inspect(pid), :room_stopped)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.warn("Process (#{inspect(ref)}, #{inspect(pid)}) is down with reason: #{reason}")

    Phoenix.PubSub.broadcast(Jellyfish.PubSub, inspect(pid), :room_crashed)

    {:noreply, state}
  end

  defp remove_room(room_id) do
    case find_room(room_id) do
      {:ok, pid} ->
        try do
          :ok = GenServer.stop(pid, :normal)
        catch
          :exit, {:noproc, {GenServer, :stop, [^pid, :normal, :infinity]}} ->
            Logger.warn(
              "During removing room #{room_id}, process exited because process didn't live already"
            )
        end

      _not_found ->
        Logger.warn("Room with id #{room_id} doesn't exist")
    end

    Logger.info("Deleted room #{inspect(room_id)}")
  end
end
