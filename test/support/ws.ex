defmodule JellyfishWeb.WS do
  @moduledoc false

  use WebSockex

  alias Jellyfish.PeerMessage
  alias Jellyfish.ServerMessage

  @spec start(String.t(), :server | :peer) :: {:ok, pid()} | {:error, term()}
  def start(url, type) do
    state = %{caller: self(), type: type}
    WebSockex.start(url, __MODULE__, state)
  end

  @spec start_link(String.t(), :server | :peer) :: {:ok, pid()} | {:error, term()}
  def start_link(url, type) do
    state = %{caller: self(), type: type}
    WebSockex.start_link(url, __MODULE__, state)
  end

  def send_auth_request(ws, token) do
    send(ws, {:authenticate, token})
  end

  def subscribe(ws, event_type) do
    proto_event_type = to_proto_event_type(event_type)

    msg = %ServerMessage{
      content:
        {:subscribe_request,
         %ServerMessage.SubscribeRequest{
           event_type: proto_event_type
         }}
    }

    :ok = send_binary_frame(ws, ServerMessage.encode(msg))

    import ExUnit.Assertions

    assert_receive %ServerMessage.SubscribeResponse{event_type: ^proto_event_type} = response
    response
  end

  def send_frame(ws, msg) do
    WebSockex.send_frame(ws, {:text, Jason.encode!(msg)})
  end

  def send_frame_raw(ws, msg) do
    WebSockex.send_frame(ws, {:text, msg})
  end

  def send_binary_frame(ws, msg) do
    WebSockex.send_frame(ws, {:binary, msg})
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    content = decode_binary(msg, state.type)
    send(state.caller, content)
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    send(state.caller, Jason.decode!(msg))
    {:ok, state}
  end

  @impl true
  def handle_info({:authenticate, token}, state) do
    request = auth_request(state.type, token)
    {:reply, {:binary, request}, state}
  end

  @impl true
  def handle_disconnect(conn_status, state) do
    send(state.caller, {:disconnected, conn_status.reason})
    {:ok, state}
  end

  defp decode_binary(msg, :peer) do
    %PeerMessage{content: {_atom, content}} = PeerMessage.decode(msg)
    content
  end

  defp decode_binary(msg, :server) do
    %ServerMessage{content: {_atom, content}} = ServerMessage.decode(msg)
    content
  end

  defp auth_request(:peer, token) do
    PeerMessage.encode(%PeerMessage{
      content: {:auth_request, %PeerMessage.AuthRequest{token: token}}
    })
  end

  defp auth_request(:server, token) do
    ServerMessage.encode(%ServerMessage{
      content: {:auth_request, %ServerMessage.AuthRequest{token: token}}
    })
  end

  defp to_proto_event_type(:server_notification), do: :EVENT_TYPE_SERVER_NOTIFICATION
  defp to_proto_event_type(:metrics), do: :EVENT_TYPE_METRICS
end
