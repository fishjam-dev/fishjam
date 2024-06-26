defmodule FishjamWeb.FallbackController do
  use FishjamWeb, :controller

  require Logger

  def call(conn, {:rpc_error, reason, room_id}) do
    case reason do
      :invalid_room_id ->
        call(conn, {:error, :bad_request, "Invalid room ID: #{room_id}"})

      not_found when not_found in [:node_not_found, :room_not_found] ->
        call(conn, {:error, :not_found, "Room #{room_id} does not exist"})

      :rpc_failed ->
        call(
          conn,
          {:error, :service_unavailable,
           "Unable to reach Fishjam instance holding room #{room_id}"}
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
