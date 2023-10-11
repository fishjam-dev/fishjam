defmodule WebHookPlug do
  @moduledoc false
  import Plug.Conn
  alias Phoenix.PubSub

  @pubsub Jellyfish.PubSub

  def init(opts) do
    # initialize options

    opts
  end

  def call(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, [])
    notification = Jason.decode!(body)

    :ok = PubSub.broadcast(@pubsub, "webhook", notification)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "OK")
  end
end
