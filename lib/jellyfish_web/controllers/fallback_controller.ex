defmodule JellyfishWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use JellyfishWeb, :controller

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(JellyfishWeb.ErrorView)
    |> render(:"404")
  end

  def error_json_respond(conn, status_code, error_msg) do
    conn
    |> put_resp_content_type("application/json")
    |> put_status(status_code)
    |> json(%{errors: error_msg})
  end
end
