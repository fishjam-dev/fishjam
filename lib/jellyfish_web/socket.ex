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
         :ok <- Logger.metadata(room_id: room_id),
         {:ok, :disconnected} <- Room.get_peer_connection_status(room_pid, peer_id) do
      state =
        state
        |> Map.put(:peer_id, peer_id)
        |> Map.put(:room_pid, room_pid)

      Logger.info("WebSocket connection from peer #{inspect(peer_id)} accepted")

      {:ok, state}
    else
      {:ok, :connected} ->
        Logger.warn(
          "WebSocket connection for peer #{inspect(state.params["peer_id"])} already exists, rejected"
        )

        {:error, :already_connected}

      {:error, :room_not_found} ->
        Logger.warn("Room not found, ignoring incoming WebSocket connection")

        {:error, :room_not_found}

      {:error, :peer_not_found} ->
        Logger.warn(
          "Peer #{inspect(state.params["peer_id"])} not found, ignoring incoming WebSocket connection"
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
    Room.set_peer_connected(state.room_pid, state.peer_id)
    {:ok, state}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :text]}, state) do
    case Jason.decode(encoded_message) do
      {:ok, %{"type" => "mediaEvent", "data" => data}} ->
        send(state.room_pid, {:media_event, state.peer_id, data})

      {:error, %Jason.DecodeError{}} ->
        Logger.warn("Failed to decode message from peer #{inspect(state.peer_id)}")

      {:ok, %{"type" => type}} ->
        Logger.warn(
          "Received message with unexpected type #{inspect(type)} from peer #{inspect(state.peer_id)}"
        )

      {:ok, _message} ->
        Logger.warn("Received message with invalid structure from peer #{inspect(state.peer_id)}")
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
    Logger.info("WebSocket associated with peer #{inspect(state.peer_id)} stopped")

    :ok
  end
end
