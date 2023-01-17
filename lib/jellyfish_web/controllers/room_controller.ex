defmodule JellyfishWeb.RoomController do
  use JellyfishWeb, :controller

  alias JellyfishWeb.RoomService

  action_fallback JellyfishWeb.FallbackController

  def index(conn, _params) do
    rooms =
      :rooms
      |> :ets.tab2list()
      |> Enum.map(fn {_id, room_pid} -> GenServer.call(room_pid, :state) end)

    render(conn, "index.json", rooms: rooms)
  end

  def create(conn, params) do
    max_peers = Map.get(params, "max_peers")

    if not is_nil(max_peers) and not is_number(max_peers) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(422)
      |> json(%{errors: "max_peers should be number if passed"})
    else
      room = GenServer.call(RoomService, {:create_room, max_peers})

      conn
      |> put_status(:created)
      |> render("show.json", room: room)
    end
  end

  def show(conn, %{"room_id" => id}) do
    case :ets.lookup(:rooms, id) do
      [{_room_id, room_pid} | _] ->
        room = GenServer.call(room_pid, :state)
        render(conn, "show.json", room: room)

      _not_found ->
        send_resp(conn, 404, "Room not found")
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case GenServer.call(RoomService, {:delete, id}) do
      :ok -> send_resp(conn, :no_content, "")
      :not_found -> send_resp(conn, 404, "Room with id #{id} doesn't exist already")
    end
  end
end
