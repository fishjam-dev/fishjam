defmodule JellyfishWeb.WS do
  @moduledoc false

  use WebSockex

  alias Jellyfish.PeerMessage
  alias Jellyfish.ServerMessage

  def start_link(url, type) do
    state = %{caller: self(), type: type}
    WebSockex.start_link(url, __MODULE__, state)
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
end
