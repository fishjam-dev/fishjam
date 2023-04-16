defmodule JellyfishWeb.WS do
  @moduledoc false

  use WebSockex

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{caller: self()})
  end

  def send_frame(ws, msg) do
    WebSockex.send_frame(ws, {:text, Jason.encode!(msg)})
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
