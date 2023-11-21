defmodule JellyfishWeb.SubscriptionController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.Room
  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback JellyfishWeb.FallbackController

  tags [:hls]

  operation :create,
    operation_id: "subscribe_tracks",
    summary: "Subscribe hls component for tracks",
    parameters: [room_id: [in: :path, description: "Room ID", type: :string]],
    request_body: {"Subscribe configuration", "application/json", ApiSpec.Subscription.Tracks},
    responses: [
      created: %Response{description: "Tracks succesfully added."},
      bad_request: ApiSpec.error("Invalid request structure"),
      not_found: ApiSpec.error("Room doesn't exist")
    ]

  def create(conn, %{"room_id" => room_id} = params) do
    with tracks <- Map.get(params, "tracks", %{}),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.hls_subscribe(room_id, tracks) do
      send_resp(conn, :created, "Successfully subscribed for tracks.")
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :hls_component_not_exists} ->
        {:error, :bad_request, "HLS component does not exist"}

      {:error, :invalid_subscribe_mode} ->
        {:error, :bad_request, "HLS component option `subscribe_mode` is set to :auto"}
    end
  end
end
