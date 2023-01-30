defmodule JellyfishWeb.ComponentController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Component
  alias Jellyfish.Room

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_id" => room_id} = params) do
    with {:ok, component_type_string} <- Map.fetch(params, "type"),
         {:ok, component_options} <- Map.fetch(params, "options"),
         {:ok, component_type} <- Component.validate_component_type(component_type_string) do
      case RoomService.find_room(room_id) do
        :not_found -> {:error, :not_found, "Room not found"}
        room_pid ->
          component = Room.add_component(room_pid, component_type, component_options)

          conn
          |> put_resp_content_type("application/json")
          |> put_status(:created)
          |> render("show.json", component: component)

      end
    else
      {:error, :invalid_component_type} -> {:error, :bad_request, "Invalid component type"}
      :error -> {:error, :bad_reguest, "Request body has invalid structure"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "id" => id}) do
    case RoomService.find_room(room_id) do
      :not_found -> {:error, :bad_request, "Room not found"}

      room_pid ->
        case Room.remove_component(room_pid, id) do
          :ok ->
            send_resp(conn, :no_content, "")

          :error -> {:error, :not_found, "Component with id #{id} doesn't exist"}
        end
    end
  end
end
