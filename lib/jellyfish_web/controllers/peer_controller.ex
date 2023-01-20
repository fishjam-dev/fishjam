defmodule JellyfishWeb.PeerController do
  use JellyfishWeb, :controller

  alias JellyfishWeb.FallbackController
  alias Jellyfish.RoomService
  alias Jellyfish.Room
  alias Jellyfish.Peer
  alias FallbackController

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_uuid" => room_uuid} = params) do
    peer_type =
      params
      |> Map.fetch!("peer_type")
      |> Peer.validate_peer_type()

    case {peer_type, RoomService.find_room(room_uuid)} do
      {:error, _} ->
        FallbackController.error_json_respond(conn, 400, "Not proper peer_type")

      {{:ok, _peer_type}, :not_found} ->
        FallbackController.error_json_respond(conn, 400, "Room not found")

      {{:ok, peer_type}, room_pid} ->
        case Room.add_peer(room_pid, peer_type) do
          {:error, :reached_peers_limit} ->
            FallbackController.error_json_respond(conn, 503, "Reached peers limit in room")

          peer ->
            conn
            |> put_resp_content_type("application/json")
            |> put_status(:created)
            |> render("show.json", peer: peer)
        end
    end
  end
end
