defmodule FishjamWeb.FallbackController do
  use FishjamWeb, :controller

  require Logger

  def call(conn, {:error, status, reason}) do
    # TODO FIXME
    Logger.warning("Generic error handler status: #{status}, reason: #{reason}")

    conn
    |> put_resp_content_type("application/json")
    |> put_status(status)
    |> json(%{errors: reason})
  end
end
