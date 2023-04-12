defmodule JellyfishWeb.PeerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.{Room, RoomService}
  alias JellyfishWeb.PeerToken

  @heartbeat_interval 30_000

  @impl true
  def child_spec(_opts) do
    # No additional processes are spawned, returning child_spec for dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl true
  def connect(state) do
    Logger.info("New incoming peer WebSocket connection, accepting")

    {:ok, state}
  end

  @impl true
  def init(state) do
    {:ok, Map.put(state, :authenticated?, false)}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :text]}, %{authenticated?: false} = state) do
    case Jason.decode(encoded_message) do
      {:ok, %{"type" => "controlMessage", "data" => %{"type" => "authRequest", "token" => token}}} ->
        with {:ok, %{peer_id: peer_id, room_id: room_id}} <- PeerToken.verify(token),
             {:ok, room_pid} <- RoomService.find_room(room_id),
             :ok <- Room.set_peer_connected(room_id, peer_id),
             :ok <- Phoenix.PubSub.subscribe(Jellyfish.PubSub, room_id) do
          Process.send_after(self(), :send_ping, @heartbeat_interval)

          message =
            %{"type" => "authenticated"}
            |> control_message()

          state =
            state
            |> Map.merge(%{
              authenticated?: true,
              peer_id: peer_id,
              room_id: room_id,
              room_pid: room_pid
            })

          Logger.info("Peer WS #{peer_id} authenticated.")

          {:reply, :ok, {:text, message}, state}
        else
          {:error, reason} ->
            Logger.warn("""
            Authentication failed, reason: #{reason}.
            Closing the connection.
            """)

            {:stop, :closed, {1000, inspect(reason)}, state}
        end

      _other ->
        Logger.warn("""
        Received message from unauthenticated peer that is not authRequest.
        Closing the connection.
        """)

        {:stop, :closed, {1000, "unauthenticated"}, state}
    end
  end

  def handle_in({encoded_message, [opcode: :text]}, state) do
    case Jason.decode(encoded_message) do
      {:ok, %{"type" => "mediaEvent", "data" => data}} ->
        send(state.room_pid, {:media_event, state.peer_id, data})

      {:error, %Jason.DecodeError{}} ->
        Logger.warn("""
        Failed to decode message from peer #{inspect(state.peer_id)}, \
        room: #{inspect(state.room_id)}
        """)

      {:ok, %{"type" => "controlMessage", "data" => data}} ->
        handle_control_message(data, state)

      {:ok, %{"type" => type}} ->
        Logger.warn("""
        Received message with unexpected type #{inspect(type)} from peer \
        #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}
        """)

      {:ok, _message} ->
        Logger.warn("""
        Received message with invalid structure from peer \
        #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}
        """)
    end

    {:ok, state}
  end

  defp handle_control_message(%{"type" => "authRequest"}, state) do
    Logger.warn("""
    Received authRequest from #{inspect(state.peer_id)}, \
    room: #{inspect(state.room_id)}, but peer already connected
    """)
  end

  defp handle_control_message(message, state) do
    Logger.warn("""
    Received unknown controlMessage: #{inspect(message)} \
    from #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}
    """)
  end

  @impl true
  def handle_info({:media_event, data}, state) when is_binary(data) do
    message =
      %{"type" => "mediaEvent", "data" => data}
      |> Jason.encode!()

    {:push, {:text, message}, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info({:stop_connection, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def handle_info(:room_crashed, state) do
    {:stop, :room_crashed, state}
  end

  @impl true
  def handle_info(:room_stopped, state) do
    {:stop, :room_stopped, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("""
    WebSocket associated with peer #{inspect(Map.get(state, :peer_id, ""))} stopped, \
    room: #{inspect(Map.get(state, :room_id, ""))}
    """)

    if Map.has_key?(state, :peer_id) do
      Phoenix.PubSub.broadcast(Jellyfish.PubSub, "server", {:peer_disconnected, state.peer_id})
    end

    :ok
  end

  defp control_message(data) do
    %{
      "type" => "controlMessage",
      "data" => data
    }
    |> Jason.encode!()
  end
end
