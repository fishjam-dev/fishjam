defmodule JellyfishWeb.RoomController do
  use JellyfishWeb, :controller

  alias Jellyfish.Room
  alias Jellyfish.RoomService

  action_fallback JellyfishWeb.FallbackController

  def index(conn, _params) do
    rooms =
      :rooms
      |> :ets.tab2list()
      |> Enum.map(fn {_id, room_pid} -> Room.get_state(room_pid) end)
      |> Enum.map(&maps_to_lists/1)

    conn
    |> put_resp_content_type("application/json")
    |> render("index.json", rooms: rooms)
  end

  def create(conn, params) do
    with max_peers <- Map.get(params, "maxPeers"),
         {:ok, room} <- RoomService.create_room(max_peers) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", room: room)
    else
      {:error, :bad_arg} -> {:error, :unprocessable_entity, "maxPeers must be a number"}
    end
  end

  def show(conn, %{"room_id" => id}) do
    case RoomService.find_room(id) do
      {:ok, room_pid} ->
        room =
          room_pid
          |> Room.get_state()
          |> maps_to_lists()

        conn
        |> put_resp_content_type("application/json")
        |> render("show.json", room: room)

      {:error, :not_found} ->
        {:error, :not_found, "Room #{id} does not exist"}
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        {:error, :not_found, "Room #{id} doest not exist"}
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
