defmodule JellyfishWeb.PeerController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Room
  alias Jellyfish.Peer

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_uuid" => room_uuid} = params) do
    peer_type =
      params
      |> Map.fetch!("peer_type")
      |> Peer.validate_peer_type()

    case {peer_type, RoomService.find_room(room_uuid)} do
      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Not proper peer_type"})

      {{:ok, _peer_type}, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(400)
        |> json(%{errors: "Room not found"})

      {{:ok, peer_type}, room_pid} ->
        peer = Room.add_peer(room_pid, peer_type)

        conn
        |> put_status(:created)
        |> render("show.json", peer: peer)
    end
  end
end
