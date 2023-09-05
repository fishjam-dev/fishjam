defmodule JellyfishWeb.ServerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    SubscribeRequest,
    SubscribeResponse
  }

  alias Jellyfish.Event

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
          Logger.warning("""
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
        Logger.warning("""
        Received message on server WS that is not auth_request.
        Closing the connection.

        Message: #{inspect(encoded_message)}
        """)

        {:stop, :closed, {1000, "invalid auth request"}, state}
    end
  end

  def handle_in({encoded_message, [opcode: :binary]}, state) do
    case ServerMessage.decode(encoded_message) do
      %ServerMessage{
        content: {:subscribe_request, %SubscribeRequest{event_type: proto_event_type}}
      } ->
        event_type = from_proto_event_type(proto_event_type)
        state = ensure_subscribed(event_type, state)

        msg = %ServerMessage{
          content: {:subscribe_response, %SubscribeResponse{event_type: proto_event_type}}
        }

        {:reply, :ok, {:binary, ServerMessage.encode(msg)}, state}

      other ->
        unexpected_message_error(other, state)
    end
  end

  def handle_in({encoded_message, [opcode: _type]}, state) do
    unexpected_message_error(encoded_message, state)
  end

  defp unexpected_message_error(msg, state) do
    Logger.warning("""
    Received unexpected message on server WS.
    Closing the connection.

    Message: #{inspect(msg)}
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

  defp from_proto_event_type(:EVENT_TYPE_SERVER_NOTIFICATION), do: :server_notification
  defp from_proto_event_type(:EVENT_TYPE_METRICS), do: :metrics
end
