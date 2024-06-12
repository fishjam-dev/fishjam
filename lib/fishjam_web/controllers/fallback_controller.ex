defmodule FishjamWeb.FallbackController do
  use FishjamWeb, :controller

  require Logger

  def call(conn, {:error, rpc_error_reason}) do
    case rpc_error_reason do
      :invalid_room_id ->
        call(conn, {:error, :bad_request, "Invalid room ID"})

      not_found when not_found in [:node_not_found, :room_not_found] ->
        call(conn, {:error, :not_found, "Room with this ID does not exist"})

      :rpc_failed ->
        call(
          conn,
          {:error, :service_unavailable,
           "Unable to reach Fishjam instance holding room with this ID"}
        )
    end
  end

  def call(conn, {:error, status, reason}) do
    Logger.debug("Generic error handler status: #{status}, reason: #{reason}")

    conn
    |> put_resp_content_type("application/json")
    |> put_status(status)
    |> json(%{errors: reason})
  end
end
