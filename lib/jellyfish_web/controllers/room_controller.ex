defmodule JellyfishWeb.RoomController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback JellyfishWeb.FallbackController

  tags [:room]

  operation :index,
    summary: "Show information about all rooms",
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RoomsListingResponse),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  operation :create,
    summary: "Creates a room",
    request_body: {"Room configuration", "application/json", ApiSpec.Room.Config},
    responses: [
      created: ApiSpec.data("Room successfully created", ApiSpec.RoomCreateDetailsResponse),
      bad_request: ApiSpec.error("Invalid request structure"),
      unauthorized: ApiSpec.error("Unauthorized")
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
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized")
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
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized")
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
         video_codec <- Map.get(params, "videoCodec"),
         room_id <- Map.get(params, "id"),
         {:ok, room, jellyfish_address} <-
           RoomService.create_room(max_peers, video_codec, room_id) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", room: room, jellyfish_address: jellyfish_address)
    else
      {:error, :invalid_max_peers} ->
        {:error, :bad_request, "maxPeers must be a number"}

      {:error, :invalid_video_codec} ->
        {:error, :bad_request, "videoCodec must be 'h264' or 'vp8'"}

      {:error, :already_started} ->
        {:error, :bad_request, "room already started on server"}
    end
  end

  def show(conn, %{"room_id" => id}) do
    case RoomService.get_room(id) do
      {:ok, room} ->
        room = maps_to_lists(room)

        conn
        |> put_resp_content_type("application/json")
        |> render("show.json", room: room)

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{id} does not exist"}
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{id} does not exist"}
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
