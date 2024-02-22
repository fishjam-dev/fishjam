defmodule JellyfishWeb.PeerController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.Peer
  alias Jellyfish.Room
  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias JellyfishWeb.PeerToken
  alias OpenApiSpex.{Response, Schema}

  action_fallback JellyfishWeb.FallbackController

  tags [:room]

  security(%{"authorization" => []})

  operation :create,
    operation_id: "add_peer",
    summary: "Create peer",
    parameters: [
      room_id: [
        in: :path,
        description: "Room id",
        type: :string
      ]
    ],
    request_body:
      {"Peer specification", "application/json",
       %Schema{
         type: :object,
         properties: %{
           options: ApiSpec.Peer.Options,
           type: ApiSpec.Peer.Type
         },
         required: [:type, :options]
       }},
    responses: [
      created: ApiSpec.data("Peer successfully created", ApiSpec.PeerDetailsResponse),
      bad_request: ApiSpec.error("Invalid request body structure"),
      not_found: ApiSpec.error("Room doesn't exist"),
      service_unavailable: ApiSpec.error("Peer limit has been reached"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  operation :delete,
    operation_id: "delete_peer",
    summary: "Delete peer",
    parameters: [
      room_id: [
        in: :path,
        description: "Room ID",
        type: :string
      ],
      id: [
        in: :path,
        description: "Peer id",
        type: :string
      ]
    ],
    responses: [
      no_content: %Response{description: "Peer successfully deleted"},
      not_found: ApiSpec.error("Room ID or Peer ID references a resource that doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  def create(conn, %{"room_id" => room_id} = params) do
    # the room may crash between fetching its
    # pid and adding a new peer to it
    # in such a case, the controller will fail
    # and Phoenix will return 500
    with peer_options <- Map.get(params, "options", %{}),
         {:ok, peer_type_string} <- Map.fetch(params, "type"),
         {:ok, peer_type} <- Peer.parse_type(peer_type_string),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         {:ok, peer} <- Room.add_peer(room_id, peer_type, peer_options) do
      assigns = [peer: peer, token: PeerToken.generate(%{peer_id: peer.id, room_id: room_id})]

      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", assigns)
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, :invalid_type} ->
        {:error, :bad_request, "Invalid peer type"}

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :reached_peers_limit} ->
        {:error, :service_unavailable, "Reached peer limit in room #{room_id}"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "id" => id}) do
    with {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.remove_peer(room_id, id) do
      send_resp(conn, :no_content, "")
    else
      {:error, :room_not_found} -> {:error, :not_found, "Room #{room_id} does not exist"}
      {:error, :peer_not_found} -> {:error, :not_found, "Peer #{id} does not exist"}
    end
  end
end
