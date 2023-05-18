defmodule JellyfishWeb.ServerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    ComponentCrashed,
    PeerConnected,
    PeerCrashed,
    PeerDisconnected,
    RoomCrashed
  }

  @heartbeat_interval 30_000

  @impl true
  def child_spec(_opts), do: :ignore

  @impl true
  def connect(state) do
    Logger.info("New incoming server WebSocket connection, accepting")

    {:ok, state}
  end

  @impl true
  def init(state) do
    {:ok, Map.put(state, :authenticated?, false)}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :binary]}, %{authenticated?: false} = state) do
    case ServerMessage.decode(encoded_message) do
      %ServerMessage{content: {:auth_request, %AuthRequest{token: token}}} ->
        if token == Application.fetch_env!(:jellyfish, :server_api_token) do
          :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, "server")
          Process.send_after(self(), :send_ping, @heartbeat_interval)

          encoded_message =
            ServerMessage.encode(%ServerMessage{content: {:authenticated, %Authenticated{}}})

          state = %{state | authenticated?: true}

          Logger.info("Server WS authenticated.")

          {:reply, :ok, {:binary, encoded_message}, state}
        else
          Logger.warn("""
          Authentication failed, reason: invalid token.
          Closing the connection.
          """)

          # TODO
          # this is not in the official Phoenix documentation
          # but in the websock_adapter
          # https://github.com/phoenixframework/websock_adapter/blob/main/lib/websock_adapter/cowboy_adapter.ex#L74
          {:stop, :closed, {1000, "invalid token"}, state}
        end

      _other ->
        Logger.warn("""
        Received message on server WS that is not auth_request.
        Closing the connection.

        Message: #{inspect(encoded_message)}
        """)

        {:stop, :closed, {1000, "invalid auth request"}, state}
    end
  end

  def handle_in({encoded_message, [opcode: _type]}, state) do
    Logger.warn("""
    Received message on server WS.
    Server WS doesn't expect to receive any messages.
    Closing the connection.

    Message: #{inspect(encoded_message)}
    """)

    {:stop, :closed, {1003, "operation not allowed"}, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(msg, state) do
    msg =
      case msg do
        {:room_crashed, room_id} ->
          %ServerMessage{content: {:room_crashed, %RoomCrashed{room_id: room_id}}}

        {:peer_connected, room_id, peer_id} ->
          %ServerMessage{
            content: {:peer_connected, %PeerConnected{room_id: room_id, peer_id: peer_id}}
          }

        {:peer_disconnected, room_id, peer_id} ->
          %ServerMessage{
            content: {:peer_disconnected, %PeerDisconnected{room_id: room_id, peer_id: peer_id}}
          }

        {:peer_crashed, room_id, peer_id} ->
          %ServerMessage{
            content: {:peer_crashed, %PeerCrashed{room_id: room_id, peer_id: peer_id}}
          }

        {:component_crashed, room_id, component_id} ->
          %ServerMessage{
            content:
              {:component_crashed,
               %ComponentCrashed{room_id: room_id, component_id: component_id}}
          }
      end

    encoded_msg = ServerMessage.encode(msg)

    {:push, {:binary, encoded_msg}, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("Server WebSocket stopped #{inspect(reason)}")
    :ok
  end
end
