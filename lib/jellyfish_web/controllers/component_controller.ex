defmodule JellyfishWeb.ComponentController do
  use JellyfishWeb, :controller

  alias Jellyfish.Component
  alias Jellyfish.Room
  alias Jellyfish.RoomService

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_id" => room_id} = params) do
    with component_options <- Map.get(params, "options"),
         {:ok, component_type_string} <- Map.fetch(params, "type"),
         {:ok, component_type} <- Component.validate_component_type(component_type_string),
         {:ok, room_pid} <- RoomService.find_room(room_id),
         {:ok, component} <- Room.add_component(room_pid, component_type, component_options) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", component: component)
    else
      :error -> {:error, :bad_request, "Invalid request body structure"}
      {:error, :invalid_type} -> {:error, :bad_request, "Invalid component type"}
      {:error, :not_found} -> {:error, :not_found, "Room #{room_id} does not exist"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "id" => id}) do
    with {:ok, room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.remove_component(room_pid, id) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} -> {:error, :not_found, "Room #{room_id} does not exist"}
      {:error, :component_not_found} -> {:error, :not_found, "Component #{id} does not exist"}
    end
  end
end
