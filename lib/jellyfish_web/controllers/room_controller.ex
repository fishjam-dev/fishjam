defmodule JellyfishWeb.RoomController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Room

  action_fallback JellyfishWeb.FallbackController

  def index(conn, _params) do
    rooms =
      :rooms
      |> :ets.tab2list()
      |> Enum.map(fn {_id, room_pid} -> Room.get_state(room_pid) end)

    render(conn, "index.json", rooms: rooms)
  end

  def create(conn, params) do
    max_peers = Map.get(params, "max_peers")

    case RoomService.create_room(max_peers) do
      :bad_arg ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(422)
        |> json(%{errors: "max_peers should be number if passed"})

      room ->
        conn
        |> put_status(:created)
        |> render("show.json", room: room)
    end
  end

  def show(conn, %{"room_id" => id}) do
    case RoomService.find_room(id) do
      :not_found ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(404)
        |> json(%{errors: "Room not found"})

      room_pid ->
        room = Room.get_state(room_pid)
        render(conn, "show.json", room: room)
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok -> send_resp(conn, :no_content, "")
      :not_found -> send_resp(conn, 404, "Room with id #{id} doesn't exist already")
    end
  end
end
