defmodule JellyfishWeb.WS do
  @moduledoc false

  use WebSockex
  alias Jellyfish.Server.ControlMessage

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{caller: self()})
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
    %ControlMessage{content: {_atom, content}} = ControlMessage.decode(msg)
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
end
