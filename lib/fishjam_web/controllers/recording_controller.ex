defmodule FishjamWeb.RecordingController do
  use FishjamWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias Fishjam.Component.HLS.Recording
  alias Fishjam.Component.HLS.Local.RequestHandler
  alias FishjamWeb.ApiSpec

  alias Plug.Conn

  action_fallback FishjamWeb.FallbackController

  @playlist_content_type "application/vnd.apple.mpegurl"
  @recording_id_spec [in: :path, description: "Recording id", type: :string]

  tags [:recording]

  security(%{"authorization" => []})

  operation :index,
    operation_id: "getRecordingContent",
    summary: "Retrieve Recording (HLS) Content",
    parameters: [
      recording_id: @recording_id_spec,
      filename: [in: :path, description: "Name of the file", type: :string]
    ],
    required: [:recording_id, :filename],
    responses: [
      ok: ApiSpec.data("File was found", ApiSpec.HLS.Response),
      not_found: ApiSpec.error("File not found"),
      bad_request: ApiSpec.error("Invalid request")
    ]

  operation :show,
    operation_id: "get_recordings",
    summary: "Lists all available recordings",
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RecordingListResponse),
      not_found: ApiSpec.error("Unable to obtain recordings"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  operation :delete,
    operation_id: "delete_recording",
    summary: "Deletes the recording",
    parameters: [recording_id: @recording_id_spec],
    responses: [
      no_content: %OpenApiSpex.Response{description: "Successfully deleted recording"},
      not_found: ApiSpec.error("Recording doesn't exist"),
      bad_request: ApiSpec.error("Invalid recording"),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  def index(conn, %{"recording_id" => recording_id, "filename" => filename}) do
    with {:ok, file} <-
           RequestHandler.handle_recording_request(recording_id, filename) do
      conn =
        if String.ends_with?(filename, ".m3u8"),
          do: put_resp_content_type(conn, @playlist_content_type, nil),
          else: conn

      Conn.send_resp(conn, 200, file)
    else
      {:error, :invalid_recording} ->
        {:error, :bad_request, "Invalid recording, got: #{recording_id}"}

      {:error, :invalid_path} ->
        {:error, :bad_request, "Invalid filename, got: #{filename}"}

      {:error, _reason} ->
        {:error, :not_found, "File not found"}
    end
  end

  def show(conn, _params) do
    case Recording.list_all() do
      {:ok, recordings} ->
        conn
        |> put_resp_content_type("application/json")
        |> render("show.json", recordings: recordings)

      :error ->
        {:error, :not_found, "Unable to obtain recordings"}
    end
  end

  def delete(conn, %{"recording_id" => recording_id}) do
    case Recording.delete(recording_id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        {:error, :not_found, "Recording not found"}

      {:error, :invalid_recording} ->
        {:error, :bad_request, "Invalid recording id, got: #{recording_id}"}
    end
  end
end
