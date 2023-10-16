defmodule Jellyfish.WebhookNotifier do
  @moduledoc """
  Module responsible for sending notifications to webhooks.
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
    {:ok, %{}, {:continue, nil}}
  end

  @impl true
  def handle_continue(_continue_arg, state) do
    :ok = Event.subscribe(:server_notification)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_room_webhook, room_id, webhook_url}, state) do
    {:noreply, Map.put(state, room_id, webhook_url)}
  end

  @impl true
  def handle_info(msg, state) do
    {atom, %{room_id: room_id}} = content = Event.to_proto(msg)
    notification = %ServerMessage{content: content} |> ServerMessage.encode()

    webhook_url = Map.get(state, room_id)
    send_webhook_notification(notification, webhook_url)

    state =
      if atom in [:room_crashed, :room_deleted] do
        Map.delete(state, room_id)
      else
        state
      end

    {:noreply, state}
  end

  defp send_webhook_notification(notification, webhook_url) when not is_nil(webhook_url) do
    case HTTPoison.post(webhook_url, Jason.encode!(%{notification: notification})) do
      {:ok, _result} ->
        nil

      {:error, error} ->
        Logger.warning(
          "Sending notification through webhook fails with error: #{inspect(error)} on address #{webhook_url}"
        )
    end
  end

  defp send_webhook_notification(_notification, _webhook_url), do: :ok
end
