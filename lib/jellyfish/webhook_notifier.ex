defmodule Jellyfish.WebhookNotifier do
  @moduledoc """
  Module responsible for sending notifications through webhooks.
  """

  use GenServer

  require Logger

  alias Jellyfish.Event
  alias Jellyfish.ServerMessage

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def add_webhook(room_id, webhook_url) do
    GenServer.cast(__MODULE__, {:add_room_webhook, room_id, webhook_url})
  end

  @impl true
  def init(_opts) do
    :ok = Event.subscribe(:server_notification)
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_room_webhook, room_id, webhook_url}, state) do
    {:noreply, Map.put(state, room_id, webhook_url)}
  end

  @impl true
  def handle_info(msg, state) do
    {event_type, %{room_id: room_id}} = content = Event.to_proto(msg)
    notification = %ServerMessage{content: content} |> ServerMessage.encode()

    webhook_url = Map.get(state, room_id)
    send_webhook_notification(notification, webhook_url)

    state =
      if event_type in [:room_crashed, :room_deleted] do
        Map.delete(state, room_id)
      else
        state
      end

    {:noreply, state}
  end

  defp send_webhook_notification(notification, webhook_url) when not is_nil(webhook_url) do
    case HTTPoison.post(
           webhook_url,
           notification,
           [{"Content-Type", "application/protobuf"}]
         ) do
      {:ok, result} when result.status_code >= 200 and result.status_code < 300 ->
        nil

      {:ok, result} ->
        Logger.warning(
          "Notification send through webhook: #{webhook_url}, but resulted with not sucessful response: #{inspect(result)}"
        )

      {:error, error} ->
        Logger.warning(
          "Couldn't send notification through webhook: #{webhook_url}, reason: #{inspect(error)}"
        )
    end
  end

  defp send_webhook_notification(_notification, _webhook_url), do: :ok
end
