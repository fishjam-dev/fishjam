defmodule JellyfishWeb.PeerController do
  use JellyfishWeb, :controller

  alias Jellyfish.RoomService
  alias Jellyfish.Room
  alias Jellyfish.Peer

  action_fallback JellyfishWeb.FallbackController

  def create(conn, %{"room_id" => room_id} = params) do
    with {:ok, peer_type_string} <- Map.fetch(params, "type"),
         {:ok, peer_type} <- Peer.validate_peer_type(peer_type_string) do
      case RoomService.find_room(room_id) do
        :not_found ->
          {:error, :not_found, "Room not found"}

        room_pid ->
          case Room.add_peer(room_pid, peer_type) do
            {:error, :reached_peers_limit} ->
              {:error, :service_unavailable, "Reached peer limit in the room"}

            peer ->
              conn
              |> put_resp_content_type("application/json")
              |> put_status(:created)
              |> render("show.json", peer: peer)
          end
      end
    else
      {:error, :invalid_peer_type} -> {:error, :bad_request, "Invalid peer type"}
      :error -> {:error, :bad_request, "Request body has invalid structure"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "id" => id}) do
    case RoomService.find_room(room_id) do
      :not_found ->
        {:error, :not_found, "Room not found"}

      room_pid ->
        case Room.remove_peer(room_pid, id) do
          :ok -> send_resp(conn, :no_content, "")
          :error -> {:error, :not_found, "Peer with id #{id} doesn't exist"}
        end
    end
  end
end
