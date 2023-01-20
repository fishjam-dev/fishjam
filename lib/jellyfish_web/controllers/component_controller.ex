defmodule JellyfishWeb.ComponentController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Component
  alias Jellyfish.Room

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_uuid" => room_uuid} = params) do
    component_type =
      params
      |> Map.fetch!("component_type")
      |> Component.validate_component_type()

    case {component_type, RoomService.find_room(room_uuid)} do
      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Not proper component type"})

      {{:ok, _component_type}, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Room not found"})

      {{:ok, component_type}, room_pid} ->
        component = Room.add_component(room_pid, component_type)

        conn
        |> put_status(:created)
        |> render("show.json", component: component)
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
        case Room.remove_component(room_pid, id) do
          :ok ->
            send_resp(conn, :no_content, "")

          :error ->
            conn
            |> put_resp_content_type("application/json")
            |> put_status(404)
            |> json(%{errors: "Component with id #{id} doesn't exist"})
        end
    end
  end
end
