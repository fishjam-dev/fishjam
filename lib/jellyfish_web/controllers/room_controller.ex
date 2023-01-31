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
      |> Enum.map(&maps_to_lists/1)
      |> IO.inspect()

    render(conn, "index.json", rooms: rooms)
  end

  def create(conn, params) do
    max_peers = Map.get(params, "maxPeers")

    case RoomService.create_room(max_peers) do
      :bad_arg -> {:error, :unprocessable_entity, "maxPeers should be number if passed"}
      room ->
        conn
        |> put_status(:created)
        |> render("show.json", room: room)
    end
  end

  def show(conn, %{"room_id" => id}) do
    case RoomService.find_room(id) do
      :not_found -> {:error, :not_found, "Room not found"}

      room_pid ->
        room =
          room_pid
          |> Room.get_state()
          |> maps_to_lists()

        render(conn, "show.json", room: room)
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok -> send_resp(conn, :no_content, "")
      :not_found -> {:error, :not_found, "Room with id #{id} doesn't exist already"}
    end
  end

  defp maps_to_lists(room) do
    # Values of component/peer maps also contain the ids
    components =
      room.components
      |> Enum.map(fn {_id, component} -> component end)

    peers =
      room.peers
      |> Enum.map(fn {_id, peer} -> peer end)

    %{room | components: components, peers: peers}
  end
end
