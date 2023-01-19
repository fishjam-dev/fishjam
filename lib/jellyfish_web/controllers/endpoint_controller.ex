defmodule JellyfishWeb.EndpointController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Endpoint
  alias Jellyfish.Room

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_uuid" => room_uuid} = params) do
    endpoint_type =
      params
      |> Map.fetch!("endpoint_type")
      |> Endpoint.validate_endpoint_type()

    case {endpoint_type, RoomService.find_room(room_uuid)} do
      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Not proper endpoint type"})

      {{:ok, _endpoint_type}, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Room not found"})

      {{:ok, endpoint_type}, room_pid} ->
        endpoint = Room.add_endpoint(room_pid, endpoint_type)

        conn
        |> put_status(:created)
        |> render("show.json", endpoint: endpoint)
    end
  end

  def delete(conn, %{"room_uuid" => room_id, "id" => id}) do
    case RoomService.find_room(room_id) do
      :not_found ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Room not found"})

      room_pid ->
        case Room.remove_endpoint(room_pid, id) do
          :ok ->
            send_resp(conn, :no_content, "")

          :error ->
            conn
            |> put_resp_content_type("application/json")
            |> put_status(404)
            |> json(%{errors: "Endpoint with id #{id} doesn't exist"})
        end
    end
  end
end
