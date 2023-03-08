defmodule JellyfishWeb.PeerController do
  use JellyfishWeb, :controller

  alias Jellyfish.Peer
  alias Jellyfish.Room
  alias Jellyfish.RoomService

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_id" => room_id} = params) do
    with {:ok, peer_type_string} <- Map.fetch(params, "type"),
         {:ok, peer_type} <- Peer.parse_type(peer_type_string),
         {:ok, room_pid} <- RoomService.find_room(room_id),
         {:ok, peer} <- Room.add_peer(room_pid, peer_type) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", peer: peer)
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
    with {:ok, room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.remove_peer(room_pid, id) do
      send_resp(conn, :no_content, "")
    else
      {:error, :room_not_found} -> {:error, :not_found, "Room #{room_id} does not exist"}
      {:error, :peer_not_found} -> {:error, :not_found, "Peer #{id} does not exist"}
    end
  end
end
