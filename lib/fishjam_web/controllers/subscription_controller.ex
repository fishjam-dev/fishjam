defmodule FishjamWeb.SubscriptionController do
  use FishjamWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Fishjam.Cluster.{Room, RoomService}
  alias FishjamWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback FishjamWeb.FallbackController

  tags [:room]

  security(%{"authorization" => []})

  operation :create,
    operation_id: "subscribe_to",
    summary: "Subscribe component to the tracks of peers or components",
    parameters: [
      room_id: [in: :path, description: "Room ID", type: :string],
      component_id: [in: :path, description: "Component ID", type: :string]
    ],
    request_body: {"Subscribe configuration", "application/json", ApiSpec.Subscription.Origins},
    responses: [
      created: %Response{description: "Tracks succesfully added."},
      bad_request: ApiSpec.error("Invalid request structure"),
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized"),
      service_unavailable: ApiSpec.error("Service temporarily unavailable")
    ]

  def create(conn, %{"room_id" => room_id, "component_id" => component_id} = params) do
    with {:ok, origins} <- Map.fetch(params, "origins"),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.subscribe(room_id, component_id, origins) do
      send_resp(conn, :created, "Successfully subscribed for tracks")
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, :invalid_room_id} ->
        {:error, :bad_request, "Invalid room ID: #{room_id}"}

      {:error, not_found} when not_found in [:room_not_found, :node_not_found] ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :rpc_failed} ->
        {:error, :service_unavailable, "Unable to reach Fishjam instance holding room #{room_id}"}

      {:error, :component_not_exists} ->
        {:error, :bad_request, "Component #{component_id} does not exist"}

      {:error, :invalid_component_type} ->
        {:error, :bad_request,
         "Subscribe mode is supported only for HLS and Recording components"}

      {:error, :invalid_subscribe_mode} ->
        {:error, :bad_request,
         "Component #{component_id} option `subscribe_mode` is set to :auto"}
    end
  end
end
