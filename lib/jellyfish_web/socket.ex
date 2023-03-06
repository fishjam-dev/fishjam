defmodule JellyfishWeb.Socket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport

  require Logger

  alias Jellyfish.{Room, RoomService}

  @impl true
  def child_spec(_opts) do
    # No additional processes are spawned, returning child_spec for dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl true
  def connect(state) do
    Logger.info("New incoming WebSocket connection...")

    with {:ok, peer_id} <- Map.fetch(state.params, "peer_id"),
         {:ok, room_id} <- Map.fetch(state.params, "room_id"),
         {:ok, room_pid} <- RoomService.find_room(room_id),
         {:ok, :disconnected} <- Room.get_peer_connection_status(room_pid, peer_id) do
      state =
        state
        |> Map.put(:room_id, room_id)
        |> Map.put(:peer_id, peer_id)

      Logger.info(
        "WebSocket connection from peer #{inspect(peer_id)} accepted, room #{inspect(room_id)}"
      )

      {:ok, state}
    else
      {:ok, :connected} ->
        Logger.warn(
          "WebSocket connection for peer #{inspect(state.params["peer_id"])} in room #{inspect(state.params["room_id"])} already exists, rejected"
        )

        {:error, :already_connected}

      {:error, :room_not_found} ->
        Logger.warn(
          "Room #{inspect(state.params["room_id"])} not found, ignoring incoming WebSocket connection"
        )

        {:error, :room_not_found}

      {:error, :peer_not_found} ->
        Logger.warn(
          "Peer #{inspect(state.params["peer_id"])} not found in room #{inspect(state.params["room_id"])}, ignoring incoming WebSocket connection"
        )

        {:error, :peer_not_found}

      :error ->
        Logger.warn(
          "No room_id/peer_id in connection params, ignoring incoming WebSocket connection"
        )

        {:error, :no_params}
    end
  end

  @impl true
  def init(state) do
    with {:ok, room_pid} <- RoomService.find_room(state.room_id),
         :ok <- Room.set_peer_connected(room_pid, state.peer_id) do
    else
      # these cases should not happen, if requirements were properly checked in `connect/1`
      {:error, :room_not_found} ->
        Logger.error(
          "Trying to connect signaling from non existent peer #{inspect(state.peer_id)}), room: #{inspect(state.room_id)}"
        )

      {:error, :peer_not_found} ->
        Logger.error(
          "Trying to connect signaling to non existent room #{inspect(state.room_id)})"
        )
    end

    {:ok, state}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :text]}, state) do
    case Jason.decode(encoded_message) do
      {:ok, %{"type" => "mediaEvent", "data" => data}} ->
        case RoomService.find_room(state.room_id) do
          {:ok, room_pid} ->
            send(room_pid, {:media_event, state.peer_id, data})

          {:error, :room_not_found} ->
            Logger.warn(
              "Trying to send Media Event to room #{inspect(state.room_id)}) that does not exists "
            )
        end

      {:error, %Jason.DecodeError{}} ->
        Logger.warn(
          "Failed to decode message from peer #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}"
        )

      {:ok, %{"type" => type}} ->
        Logger.warn(
          "Received message with unexpected type #{inspect(type)} from peer #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}"
        )

      {:ok, _message} ->
        Logger.warn(
          "Received message with invalid structure from peer #{inspect(state.peer_id)}, room: #{inspect(state.room_id)}"
        )
    end

    {:ok, state}
  end

  @impl true
  def handle_info({:media_event, data}, state) when is_binary(data) do
    message =
      %{"type" => "mediaEvent", "data" => data}
      |> Jason.encode!()

    {:push, {:text, message}, state}
  end

  @impl true
  def handle_info({:stop_connection, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info(
      "WebSocket associated with peer #{inspect(state.peer_id)} stopped, room: #{inspect(state.room_id)}"
    )

    :ok
  end
end
