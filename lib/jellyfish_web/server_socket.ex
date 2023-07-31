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
    HlsPlayable,
    MetricsReport,
    PeerConnected,
    PeerCrashed,
    PeerDisconnected,
    RoomCrashed,
    RoomCreated,
    RoomDeleted,
    SubscribeRequest,
    SubscribeResponse
  }

  alias Jellyfish.ServerMessage.SubscribeResponse.{RoomNotFound, RoomsState, RoomState}

  @heartbeat_interval 30_000
  @valid_subscribe_topics [:server_notification, :metrics]

  @impl true
  def child_spec(_opts), do: :ignore

  @impl true
  def connect(state) do
    Logger.info("New incoming server WebSocket connection, accepting")

    {:ok, state}
  end

  @impl true
  def init(state) do
    state =
      state
      |> Map.merge(%{
        authenticated?: false,
        subscriptions: MapSet.new()
      })

    {:ok, state}
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
         {:ok, response, state} <- handle_subscribe(request, state) do
      reply =
        %ServerMessage{
          content: {:subscribe_response, response}
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

  defp handle_subscribe(
         %SubscribeRequest{
           id: id,
           event_type: {topic, event_type}
         },
         state
       )
       when topic in @valid_subscribe_topics do
    unless MapSet.member?(state.subscriptions, topic) do
      :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, Atom.to_string(topic))
    end

    state = update_in(state.subscriptions, &MapSet.put(&1, topic))

    content =
      case event_type do
        %SubscribeRequest.ServerNotification{room_id: {_variant, option}} ->
          get_room_state(option)

        %SubscribeRequest.Metrics{} ->
          nil
      end

    {:ok, %SubscribeResponse{id: id, content: content}, state}
  end

  defp handle_subscribe(request, _state), do: {:error, request}

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(msg, state) do
    content = to_proto_notification(msg)
    encoded_msg = %ServerMessage{content: content} |> ServerMessage.encode()
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
          component: to_proto_component(&1)
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

    config =
      room.config
      |> Map.update!(:video_codec, &to_proto_codec/1)
      |> then(&struct!(RoomState.Config, &1))

    %RoomState{id: room.id, config: config, peers: peers, components: components}
  end

  defp to_proto_notification({:room_created, room_id}),
    do: {:room_created, %RoomCreated{room_id: room_id}}

  defp to_proto_notification({:room_deleted, room_id}),
    do: {:room_deleted, %RoomDeleted{room_id: room_id}}

  defp to_proto_notification({:room_crashed, room_id}),
    do: {:room_crashed, %RoomCrashed{room_id: room_id}}

  defp to_proto_notification({:peer_connected, room_id, peer_id}),
    do: {:peer_connected, %PeerConnected{room_id: room_id, peer_id: peer_id}}

  defp to_proto_notification({:peer_disconnected, room_id, peer_id}),
    do: {:peer_disconnected, %PeerDisconnected{room_id: room_id, peer_id: peer_id}}

  defp to_proto_notification({:peer_crashed, room_id, peer_id}),
    do: {:peer_crashed, %PeerCrashed{room_id: room_id, peer_id: peer_id}}

  defp to_proto_notification({:component_crashed, room_id, component_id}),
    do: {:component_crashed, %ComponentCrashed{room_id: room_id, component_id: component_id}}

  defp to_proto_notification({:metrics, report}),
    do: {:metrics_report, %MetricsReport{metrics: report}}

  defp to_proto_notification({:hls_playable, room_id, component_id}),
    do: {:hls_playable, %HlsPlayable{room_id: room_id, component_id: component_id}}

  defp to_proto_type(Jellyfish.Peer.WebRTC), do: :TYPE_WEBRTC

  defp to_proto_codec(:h264), do: :CODEC_H264
  defp to_proto_codec(:vp8), do: :CODEC_VP8
  defp to_proto_codec(nil), do: :CODEC_UNSPECIFIED

  defp to_proto_status(:disconnected), do: :STATUS_DISCONNECTED
  defp to_proto_status(:connected), do: :STATUS_CONNECTED

  defp to_proto_component(%{type: Jellyfish.Component.HLS, metadata: %{playable: playable}}),
    do: {:hls, %RoomState.Component.Hls{playable: playable}}

  defp to_proto_component(%{type: Jellyfish.Component.RTSP}),
    do: {:rtsp, %RoomState.Component.Rtsp{}}
end
