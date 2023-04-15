defmodule JellyfishWeb.ServerSocket do
  @moduledoc false
  @behaviour Phoenix.Socket.Transport
  require Logger

  @heartbeat_interval 30_000

  @impl true
  def child_spec(_opts), do: :ignore

  @impl true
  def connect(state) do
    Logger.info("New incoming server WebSocket connection, accepting")

    {:ok, state}
  end

  @impl true
  def init(state) do
    {:ok, Map.put(state, :authenticated?, false)}
  end

  @impl true
  def handle_in({encoded_message, [opcode: :text]}, %{authenticated?: false} = state) do
    case Jason.decode(encoded_message) do
      {:ok, %{"type" => "controlMessage", "data" => %{"type" => "authRequest", "token" => token}}} ->
        if token == Application.fetch_env!(:jellyfish, :server_api_token) do
          :ok = Phoenix.PubSub.subscribe(Jellyfish.PubSub, "server")
          Process.send_after(self(), :send_ping, @heartbeat_interval)

          message =
            %{"type" => "authenticated"}
            |> control_message()

          state = %{state | authenticated?: true}

          Logger.info("Server WS authenticated.")

          {:reply, :ok, {:text, message}, state}
        else
          Logger.warn("""
          Authentication failed, reason: invalid token.
          Closing the connection.
          """)

          # TODO
          # this is not in the official Phoenix documentation
          # but in the websock_adapter
          # https://github.com/phoenixframework/websock_adapter/blob/main/lib/websock_adapter/cowboy_adapter.ex#L74
          {:stop, :closed, {1000, "invalid token"}, state}
        end

      _other ->
        Logger.warn("""
        Received message on server WS that is not authRequest.
        Closing the connection.

        Message: #{inspect(encoded_message)}
        """)

        {:stop, :closed, 1000, state}
    end
  end

  def handle_in({encoded_message, [opcode: :text]}, state) do
    Logger.warn("""
    Received message on server WS.
    Server WS doesn't expect to receive any messages.
    Closing the connection.

    Message: #{inspect(encoded_message)}
    """)

    {:stop, :closed, 1000, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    Process.send_after(self(), :send_ping, @heartbeat_interval)
    {:push, {:ping, ""}, state}
  end

  @impl true
  def handle_info(msg, state) do
    msg =
      case msg do
        {:peer_connected, peer_id} ->
          control_message(%{type: "peerConnected", id: peer_id})

        {:peer_disconnected, peer_id} ->
          control_message(%{type: "peerDisonnected", id: peer_id})

        {:room_crashed, room_id} ->
          control_message(%{type: "roomCrashed", id: room_id})

        {:peer_crashed, peer_id} ->
          control_message(%{type: "peerCrashed", id: peer_id})

        {:component_crashed, component_id} ->
          control_message(%{type: "componentCrashed", id: component_id})
      end

    {:push, {:text, msg}, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("Server WebSocket stopped #{inspect(reason)}")

    :ok
  end

  defp control_message(data) do
    %{
      "type" => "controlMessage",
      "data" => data
    }
    |> Jason.encode!()
  end
end
