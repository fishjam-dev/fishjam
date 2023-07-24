defmodule JellyfishWeb.ServerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.RoomService

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    RoomNotFound,
    RoomState,
    RoomStateRequest,
    SubscribeRequest,
    SubscribeResponse
  }

  alias Jellyfish.Event
  alias Jellyfish.Room

  alias Jellyfish.ServerMessage.SubscribeRequest.{Metrics, ServerNotification}
  alias Jellyfish.ServerMessage.SubscribeResponse.RoomStates

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
    with %ServerMessage{content: content} <- ServerMessage.decode(encoded_message),
         {:ok, ret_val} <- handle_message(content, state) do
      ret_val
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

  defp handle_message({:room_state_request, %RoomStateRequest{room_id: room_id}}, state) do
    case Room.request_state(room_id) do
      :ok ->
        {:ok, {:ok, state}}

      {:error, :room_not_found} ->
        msg =
          %ServerMessage{content: {:room_not_found, %RoomNotFound{room_id: room_id}}}
          |> ServerMessage.encode()

        {:ok, {:reply, :ok, {:binary, msg}, state}}
    end
  end

  defp handle_message(
         {:subscribe_request, %SubscribeRequest{id: id, event_type: {_type, event_type}}},
         state
       ) do
    with {:ok, content, state} <- handle_subscribe(event_type, state) do
      reply =
        %ServerMessage{
          content: {:subscribe_response, %SubscribeResponse{id: id, content: content}}
        }
        |> ServerMessage.encode()

      {:ok, {:reply, :ok, {:binary, reply}, state}}
    end
  end

  defp handle_message(message, state) do
    unexpected_message_error(message, state)
  end

  defp handle_subscribe(%ServerNotification{}, state) do
    state = ensure_subscribed(:server_notification, state)

    RoomService.request_all_room_ids()
    {:ok, room_ids} = await_all_room_ids()

    room_ids |> Enum.each(&Room.request_state/1)

    room_states =
      room_ids
      |> Enum.flat_map(&await_room_state/1)
      |> Enum.map(&to_room_state_message/1)

    {:ok, {:room_states, %RoomStates{rooms: room_states}}, state}
  end

  defp handle_subscribe(%Metrics{}, state) do
    state = ensure_subscribed(:metrics, state)

    {:ok, nil, state}
  end

  defp handle_subscribe(request, _state), do: {:error, request}

  defp await_all_room_ids() do
    receive do
      {:all_room_ids, all_room_ids} -> {:ok, all_room_ids}
      {:server_notification, _notification} -> await_all_room_ids()
    after
      5000 -> {:error, :timeout}
    end
  end

  defp await_room_state(room_id) do
    receive do
      {:room_state, room_state} ->
        [room_state]

      # Dump all notifications from the room until it sends its state
      {:server_notification, notification} when elem(notification, 1) == room_id ->
        await_room_state(room_id)
    after
      5000 -> []
    end
  end

  @impl true
  def handle_info({:room_state, room_state}, state) do
    room_state = to_room_state_message(room_state)
    msg = %ServerMessage{content: {:room_state, room_state}} |> ServerMessage.encode()

    {:reply, :ok, {:binary, msg}, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(msg, state) do
    content = Event.to_proto(msg)

    encoded_msg = %ServerMessage{content: content} |> ServerMessage.encode()

    {:push, {:binary, encoded_msg}, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("Server WebSocket stopped #{inspect(reason)}")
    :ok
  end

  defp ensure_subscribed(event_type, state) do
    if MapSet.member?(state.subscriptions, event_type) do
      state
    else
      :ok = Event.subscribe(event_type)
      update_in(state.subscriptions, &MapSet.put(&1, event_type))
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

    config =
      room.config
      |> Map.update!(:video_codec, &to_proto_codec/1)
      |> then(&struct!(RoomState.Config, &1))

    %RoomState{id: room.id, config: config, peers: peers, components: components}
  end

  defp to_proto_type(Jellyfish.Component.HLS), do: :TYPE_HLS
  defp to_proto_type(Jellyfish.Component.RTSP), do: :TYPE_RTSP
  defp to_proto_type(Jellyfish.Peer.WebRTC), do: :TYPE_WEBRTC

  defp to_proto_codec(:h264), do: :CODEC_H264
  defp to_proto_codec(:vp8), do: :CODEC_VP8
  defp to_proto_codec(nil), do: :CODEC_UNSPECIFIED

  defp to_proto_status(:disconnected), do: :STATUS_DISCONNECTED
  defp to_proto_status(:connected), do: :STATUS_CONNECTED
end
