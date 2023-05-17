defmodule JellyfishWeb.PeerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.{Authenticated, AuthRequest, MediaEvent}
  alias Jellyfish.{Room, RoomService}
  alias JellyfishWeb.PeerToken

  @heartbeat_interval 30_000

  @impl true
  def child_spec(_opts), do: :ignore

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
  def handle_in({encoded_message, [opcode: :binary]}, %{authenticated?: false} = state) do
    case PeerMessage.decode(encoded_message) do
      %PeerMessage{content: {:auth_request, %AuthRequest{token: token}}} ->
        with {:ok, %{peer_id: peer_id, room_id: room_id}} <- PeerToken.verify(token),
             {:ok, room_pid} <- RoomService.find_room(room_id),
             :ok <- Room.set_peer_connected(room_id, peer_id),
             :ok <- Phoenix.PubSub.subscribe(Jellyfish.PubSub, room_id) do
          Process.send_after(self(), :send_ping, @heartbeat_interval)

          encoded_message =
            PeerMessage.encode(%PeerMessage{content: {:authenticated, %Authenticated{}}})

          state =
            state
            |> Map.merge(%{
              authenticated?: true,
              peer_id: peer_id,
              room_id: room_id,
              room_pid: room_pid
            })

          Phoenix.PubSub.broadcast(
            Jellyfish.PubSub,
            "server",
            {:peer_connected, room_id, peer_id}
          )

          {:reply, :ok, {:binary, encoded_message}, state}
        else
          {:error, reason} ->
            reason = reason_to_string(reason)

            Logger.warn("""
            Authentication failed, reason: #{reason}.
            Closing the connection.
            """)

            {:stop, :closed, {1000, reason}, state}
        end

      _other ->
        Logger.warn("""
        Received message from unauthenticated peer that is not authRequest.
        Closing the connection.
        """)

        {:stop, :closed, {1000, "unauthenticated"}, state}
    end
  end

  def handle_in({encoded_message, [opcode: :binary]}, state) do
    case PeerMessage.decode(encoded_message) do
      %PeerMessage{content: {:media_event, %MediaEvent{data: data}}} ->
        Room.pass_media_event(state.room_id, state.peer_id, data)

      _other ->
        Logger.warn("""
        Received unexpected message from #{inspect(state.peer_id)}, \
        room: #{inspect(state.room_id)}
        """)
    end

    {:ok, state}
  end

  @impl true
  def handle_info({:media_event, data}, state) when is_binary(data) do
    encoded_message =
      PeerMessage.encode(%PeerMessage{content: {:media_event, %MediaEvent{data: data}}})

    {:push, {:binary, encoded_message}, state}
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
      Phoenix.PubSub.broadcast(
        Jellyfish.PubSub,
        "server",
        {:peer_disconnected, state.room_id, state.peer_id}
      )
    end

    :ok
  end

  defp reason_to_string(:invalid), do: "invalid token"
  defp reason_to_string(:missing), do: "missing token"
  defp reason_to_string(:expired), do: "expired token"
  defp reason_to_string(:room_not_found), do: "room not found"
  defp reason_to_string(:peer_not_found), do: "peer not found"
  defp reason_to_string(:peer_already_connected), do: "peer already connected"
  defp reason_to_string(other), do: "#{other}"
end
