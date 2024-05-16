defmodule Fishjam do
  @moduledoc """
  Fishjam keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @version Mix.Project.config()[:version]

  def version(), do: @version

  @spec address() :: binary()
  def address() do
    Application.fetch_env!(:fishjam, :address)
  end

  @spec peer_websocket_address() :: binary()
  def peer_websocket_address() do
    Application.fetch_env!(:fishjam, :address) <> "/socket/peer/websocket"
  end
end
