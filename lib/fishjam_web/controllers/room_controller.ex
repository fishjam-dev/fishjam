defmodule FishjamWeb.RoomController do
  use FishjamWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias Fishjam.Cluster.RoomService
  alias Fishjam.Room.Config
  alias FishjamWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback FishjamWeb.FallbackController

  tags [:room]

  security(%{"authorization" => []})

  operation :index,
    operation_id: "get_all_rooms",
    summary: "Show information about all rooms",
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RoomsListingResponse),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  operation :create,
    operation_id: "create_room",
    summary: "Creates a room",
    request_body: {"Room configuration", "application/json", ApiSpec.Room.Config},
    responses: [
      created: ApiSpec.data("Room successfully created", ApiSpec.RoomCreateDetailsResponse),
      bad_request: ApiSpec.error("Invalid request structure"),
      unauthorized: ApiSpec.error("Unauthorized"),
      service_unavailable: ApiSpec.error("Service temporarily unavailable")
    ]

  operation :show,
    operation_id: "get_room",
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
      bad_request: ApiSpec.error("Invalid request"),
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized"),
      service_unavailable: ApiSpec.error("Service temporarily unavailable")
    ]

  operation :delete,
    operation_id: "delete_room",
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
      bad_request: ApiSpec.error("Invalid request"),
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized"),
      service_unavailable: ApiSpec.error("Service temporarily unavailable")
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
    Logger.debug("Start creating room")

    with {:ok, config} <- Config.from_params(params),
         {:ok, room, fishjam_address} <- RoomService.create_room(config) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", room: room, fishjam_address: fishjam_address)
    else
      {:error, :invalid_max_peers} ->
        max_peers = Map.get(params, "maxPeers")

        {:error, :bad_request, "Expected maxPeers to be a number, got: #{max_peers}"}

      {:error, :invalid_video_codec} ->
        video_codec = Map.get(params, "videoCodec")

        {:error, :bad_request, "Expected videoCodec to be 'h264' or 'vp8', got: #{video_codec}"}

      {:error, :invalid_webhook_url} ->
        webhook_url = Map.get(params, "webhookUrl")
        {:error, :bad_request, "Expected webhookUrl to be valid URL, got: #{webhook_url}"}

      {:error, :invalid_purge_timeout, param} ->
        timeout = Map.get(params, param)

        {:error, :bad_request, "Expected #{param} to be a positive integer, got: #{timeout}"}

      {:error, :room_already_exists} ->
        room_id = Map.get(params, "roomId")
        {:error, :bad_request, "Cannot add room with id \"#{room_id}\" - room already exists"}

      {:error, :room_doesnt_start} ->
        room_id = Map.get(params, "roomId")
        {:error, :bad_request, "Cannot add room with id \"#{room_id}\" - unexpected error"}

      {:error, :rpc_failed} ->
        room_id = Map.get(params, "roomId")

        {:error, :service_unavailable,
         "Cannot add room with id \"#{room_id}\" - unable to communicate with designated Fishjam instance"}

      {:error, :invalid_room_id} ->
        room_id = Map.get(params, "roomId")

        {:error, :bad_request,
         "Cannot add room with id \"#{room_id}\" - roomId may contain only alphanumeric characters, hyphens and underscores"}
    end
  end

  def show(conn, %{"room_id" => id}) do
    case RoomService.get_room(id) do
      {:ok, room} ->
        room = maps_to_lists(room)

        conn
        |> put_resp_content_type("application/json")
        |> render("show.json", room: room)

      {:error, :invalid_room_id} ->
        {:error, :bad_request, "Invalid room ID: #{id}"}

      {:error, not_found} when not_found in [:room_not_found, :node_not_found] ->
        {:error, :not_found, "Room #{id} does not exist"}

      {:error, :rpc_failed} ->
        {:error, :service_unavailable, "Unable to reach Fishjam instance holding room #{id}"}
    end
  end

  def delete(conn, %{"room_id" => id}) do
    case RoomService.delete_room(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :invalid_room_id} ->
        {:error, :bad_request, "Invalid room ID: #{id}"}

      {:error, not_found} when not_found in [:room_not_found, :node_not_found] ->
        {:error, :not_found, "Room #{id} does not exist"}

      {:error, :rpc_failed} ->
        {:error, :service_unavailable, "Unable to reach Fishjam instance holding room #{id}"}
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
