defmodule JellyfishWeb.ComponentController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.Component
  alias Jellyfish.Room
  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias OpenApiSpex.{Response, Schema}

  action_fallback JellyfishWeb.FallbackController

  tags [:room]

  security(%{"authorization" => []})

  operation :create,
    operation_id: "add_component",
    summary: "Creates the component and adds it to the room",
    parameters: [
      room_id: [
        in: :path,
        type: :string,
        description: "Room ID"
      ]
    ],
    request_body:
      {"Component config", "application/json",
       %Schema{
         type: :object,
         properties: %{
           options: ApiSpec.Component.Options,
           type: ApiSpec.Component.Type
         },
         required: [:type]
       }},
    responses: [
      created: ApiSpec.data("Successfully added component", ApiSpec.ComponentDetailsResponse),
      bad_request: ApiSpec.error("Invalid request"),
      not_found: ApiSpec.error("Room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  operation :delete,
    operation_id: "delete_component",
    summary: "Delete the component from the room",
    parameters: [
      room_id: [
        in: :path,
        type: :string,
        description: "Room ID"
      ],
      id: [
        in: :path,
        type: :string,
        description: "Component ID"
      ]
    ],
    responses: [
      no_content: %Response{description: "Successfully deleted"},
      not_found: ApiSpec.error("Either component or the room doesn't exist"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  def create(conn, %{"room_id" => room_id} = params) do
    with component_options <- Map.get(params, "options", %{}),
         {:ok, component_type_string} <- Map.fetch(params, "type"),
         {:ok, component_type} <- Component.parse_type(component_type_string),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         {:ok, component} <- Room.add_component(room_id, component_type, component_options) do
      conn
      |> put_resp_content_type("application/json")
      |> put_status(:created)
      |> render("show.json", component: component)
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, {:missing_parameter, name}} ->
        {:error, :bad_request, "Required field \"#{Atom.to_string(name)}\" missing"}

      {:error, :missing_s3_credentials} ->
        {:error, :bad_request,
         "S3 credentials has to be passed either by request or at application startup as envs"}

      {:error, :overridding_credentials} ->
        {:error, :bad_request,
         "Conflicting S3 credentials supplied via environment variables and the REST API. Please provide credentials through only one method"}

      {:error, :overridding_path_prefix} ->
        {:error, :bad_request,
         "Conflicting S3 path prefix supplied via environment variables and the REST API. Please provide credentials through only one method"}

      {:error, :invalid_type} ->
        {:error, :bad_request, "Invalid component type"}

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :incompatible_codec} ->
        {:error, :bad_request, "Incompatible video codec enforced in room #{room_id}"}

      {:error, :invalid_framerate} ->
        {:error, :bad_request, "Invalid framerate passed"}

      {:error, :bad_parameter_framerate_for_audio} ->
        {:error, :bad_request,
         "Attempted to set framerate for audio component which is not supported."}

      {:error, :invalid_file_path} ->
        {:error, :bad_request, "Invalid file path"}

      {:error, :file_does_not_exist} ->
        {:error, :not_found, "File not found"}

      {:error, :unsupported_file_type} ->
        {:error, :bad_request, "Unsupported file type"}

      {:error, {:reached_components_limit, type}} ->
        {:error, :bad_request,
         "Reached #{type} components limit for component in room #{room_id}"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "id" => id}) do
    with {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.remove_component(room_id, id) do
      send_resp(conn, :no_content, "")
    else
      {:error, :room_not_found} -> {:error, :not_found, "Room #{room_id} does not exist"}
      {:error, :component_not_found} -> {:error, :not_found, "Component #{id} does not exist"}
    end
  end
end
