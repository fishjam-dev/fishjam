defmodule JellyfishWeb.RoomController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.Room
  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback JellyfishWeb.FallbackController

  tags [:room]

  operation :index,
    summary: "Show information about all rooms",
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RoomsListingResponse)
    ]

  operation :create,
    summary: "Creates a room",
    request_body: {"Room configuration", "application/json", ApiSpec.Room.Config},
    responses: [
      created: ApiSpec.data("Room successfully created", ApiSpec.RoomDetailsResponse),
      bad_request: ApiSpec.error("Invalid request structure")
    ]

  operation :show,
    summary: "Shows information about the room",
    parameters: [
      room_id: [
        in: :path,
        description: "Room ID",
        type: :string
      ]
    ],
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RoomDetailsResponse),
      not_found: ApiSpec.error("Room doesn't exist")
    ]

  operation :delete,
    summary: "Delete the room",
    parameters: [
      room_id: [
        in: :path,
        type: :string,
        description: "Room id"
      ]
    ],
    responses: [
      no_content: %Response{description: "Successfully deleted room"},
      not_found: ApiSpec.error("Room doesn't exist")
    ]

  def index(conn, _params) do
    rooms =
      RoomService.list_rooms()
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
      {:error, :bad_arg} -> {:error, :bad_request, "maxPeers must be a number"}
    end
  end

  def show(conn, %{"room_id" => id}) do
    with {:ok, room_pid} <- RoomService.find_room(id),
         true <- Process.alive?(room_pid) do
      room =
        room_pid
        |> Room.get_state()
        |> maps_to_lists()

      conn
      |> put_resp_content_type("application/json")
      |> render("show.json", room: room)
    else
      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{id} does not exist"}
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :room_not_found} ->
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
