defmodule FishjamWeb.PeerSocketHandler do
  require Logger
  alias Fishjam.{Room, RoomService}

  def connect_peer(room_id, peer_id, node_name, current_pid) do
    with {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.set_peer_connected(room_id, peer_id, node_name, current_pid) do
      :ok
    else
      error ->
        Logger.warning(
          "Error when connecting peer #{peer_id} to room #{room_id}, because: #{inspect(error)}"
        )

        error
    end
  end

  def receive_media_event(room_id, peer_id, data) do
    Room.receive_media_event(room_id, peer_id, data)
  end

  def send_message(socket_pid, msg) do
    send_msg_if_pid_exists(socket_pid, msg)
  end

  def send_media_event(socket_pid, data) do
    send_msg_if_pid_exists(socket_pid, {:media_event, data})
  end

  defp send_msg_if_pid_exists(socket_pid, msg) do
    if Process.alive?(socket_pid) do
      send(socket_pid, msg)
      :ok
    else
      :peer_socket_not_exists
    end
  end
end
