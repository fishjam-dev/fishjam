defmodule JellyfishWeb.ServerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.RoomService

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    ComponentCrashed,
    MetricsReport,
    PeerConnected,
    PeerCrashed,
    PeerDisconnected,
    RoomCrashed,
    RoomCreated,
    RoomDeleted,
    SubscribeRequest,
    SubscriptionResponse
  }

  alias Jellyfish.ServerMessage.SubscriptionResponse.{RoomNotFound, RoomsState, RoomState}

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

  def handle_in({encoded_message, [opcode: :binary]}, state) do
    with %ServerMessage{content: {:subscribe_request, request}} <-
           ServerMessage.decode(encoded_message),
         {:ok, response} <- handle_subscribe(request) do
      reply =
        %ServerMessage{
          content: {:subscription_response, response}
        }
        |> ServerMessage.encode()

      {:reply, :ok, {:binary, reply}, state}
    else
      {:error, request} ->
        unexpected_message_error(request, state)

      other ->
        unexpected_message_error(other, state)
    end
  end

  def handle_in({encoded_message, [opcode: _type]}, state) do
    unexpected_message_error(encoded_message, state)
  end

  defp unexpected_message_error(msg, state) do
    Logger.warn("""
    Received unexpected message on server WS.
    Closing the connection.

    Message: #{inspect(msg)}
    """)

    {:stop, :closed, {1003, "operation not allowed"}, state}
  end

  defp handle_subscribe(%SubscribeRequest{
         id: id,
         event_type:
           {:server_notification,
            %SubscribeRequest.ServerNotification{room_id: {_variant, option}}}
       }) do
    :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, "server_notification")

    room_state = get_room_state(option)

    {:ok, %SubscriptionResponse{id: id, content: room_state}}
  end

  defp handle_subscribe(%SubscribeRequest{
         id: id,
         event_type: {:metrics, %SubscribeRequest.Metrics{}}
       }) do
    :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, "metrics")

    {:ok, %SubscriptionResponse{id: id}}
  end

  defp handle_subscribe(request), do: {:error, request}

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(msg, state) do
    msg =
      case msg do
        {:room_created, room_id} ->
          %ServerMessage{content: {:room_created, %RoomCreated{room_id: room_id}}}

        {:room_deleted, room_id} ->
          %ServerMessage{content: {:room_deleted, %RoomDeleted{room_id: room_id}}}

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

        {:metrics, report} ->
          %ServerMessage{
            content:
              {:metrics_report,
               %MetricsReport{
                 metrics: report
               }}
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

  defp get_room_state(:OPTION_ALL) do
    rooms =
      RoomService.list_rooms()
      |> Enum.map(&to_room_state_message/1)

    {:rooms_state, %RoomsState{rooms: rooms}}
  end

  defp get_room_state(id) do
    case RoomService.get_room(id) do
      {:ok, room} ->
        room = to_room_state_message(room)
        {:room_state, room}

      {:error, :room_not_found} ->
        {:room_not_found, %RoomNotFound{id: id}}
    end
  end

  defp to_room_state_message(room) do
    components =
      room.components
      |> Map.values()
      |> Enum.map(
        &%RoomState.Component{
          id: &1.id,
          type: to_proto_type(&1.type)
        }
      )

    peers =
      room.peers
      |> Map.values()
      |> Enum.map(
        &%RoomState.Peer{
          id: &1.id,
          type: to_proto_type(&1.type),
          status: to_proto_status(&1.status)
        }
      )

    config = struct!(RoomState.Config, room.config)

    %RoomState{id: room.id, config: config, peers: peers, components: components}
  end

  defp to_proto_type(Jellyfish.Component.HLS), do: :TYPE_HLS
  defp to_proto_type(Jellyfish.Component.RTSP), do: :TYPE_RTSP
  defp to_proto_type(Jellyfish.Peer.WebRTC), do: :TYPE_WEBRTC

  defp to_proto_status(:disconnected), do: :STATUS_DISCONNECTED
  defp to_proto_status(:connected), do: :STATUS_CONNECTED
end
