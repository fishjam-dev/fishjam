defmodule JellyfishWeb.Socket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport

  alias Jellyfish.{Room, RoomService}

  @impl true
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl true
  def connect(state) do
    with {:ok, peer_id} <- Map.fetch(state.params, "peer_id"),
         {:ok, room_id} <- Map.fetch(state.params, "room_id"),
         {:ok, room_pid} <- RoomService.find_room(room_id),
         {:ok, :disconnected} <- Room.get_peer_connection_status(room_pid, peer_id) do
      state =
        state
        |> Map.put(:room_pid, room_pid)
        |> Map.put(:peer_id, peer_id)

      {:ok, state}
    else
      {:ok, :connected} -> :error
      {:error, :room_not_found} -> :error
      :error -> :error
    end
  end

  @impl true
  def init(state) do
    case Room.connect_peer(state.room_pid, state.peer_id) do
      :ok -> nil
      # TODO
      {:error, reason} -> nil
    end

    {:ok, state}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :text]}, state) do
    with {:ok, message} <- Jason.decode(encoded_message),
         {:ok, type} <- Map.fetch(message, "type"),
         {:ok, data} <- Map.fetch(message, "data") do
      case type do
        "mediaEvent" -> send(state.room_pid, {:media_event, state.peer_id, data})
        _other -> nil
      end
    else
      # TODO
      {:error, %Jason.DecodeError{}} -> :ok
      # TODO
      :error -> :ok
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
  def terminate(_reason, _state) do
    :ok
  end
end
