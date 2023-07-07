defmodule JellyfishWeb.FallbackController do
  use JellyfishWeb, :controller

  action_fallback JellyfishWeb.FallbackController

  def call(conn, {:error, status, reason}) do
    conn
    |> put_resp_content_type("application/json")
    |> put_status(status)
    |> json(%{errors: reason})
  end
end
