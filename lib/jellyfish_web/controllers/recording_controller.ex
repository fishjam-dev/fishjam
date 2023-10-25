defmodule JellyfishWeb.RecordingController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias Jellyfish.Component.HLS.{Recording, RequestHandler}
  alias JellyfishWeb.ApiSpec
  alias JellyfishWeb.ApiSpec.HLS.Response

  alias Plug.Conn

  action_fallback JellyfishWeb.FallbackController

  @playlist_content_type "application/vnd.apple.mpegurl"

  operation :index,
    summary: "Send file",
    parameters: [
      recording_id: [in: :path, description: "Recording id", type: :string],
      filename: [in: :path, description: "Name of the file", type: :string]
    ],
    required: [:recording_id, :filename],
    responses: [
      ok: ApiSpec.data("File was found", Response),
      not_found: ApiSpec.error("File not found")
    ]

  operation :show,
    operation_id: "get_recordings",
    summary: "Shows information about the room",
    parameters: [
      recording_id: [
        in: :path,
        description: "Recording ID",
        type: :string
      ]
    ],
    responses: [
      ok: ApiSpec.data("Success", ApiSpec.RecordingListResponse)
    ]

  operation :delete,
    operation_id: "delete_recording",
    summary: "Delete the recording",
    parameters: [
      recording_id: [
        in: :path,
        type: :string,
        description: "Recording id"
      ]
    ],
    responses: [
      no_content: %OpenApiSpex.Response{description: "Successfully deleted recording"},
      not_found: ApiSpec.error("Recording doesn't exist")
    ]

  def index(conn, %{"recording_id" => recording_id, "filename" => filename}) do
    with {:ok, file} <- RequestHandler.handle_recording_request(recording_id, filename) do
      conn =
        if String.ends_with?(filename, ".m3u8"),
          do: put_resp_content_type(conn, @playlist_content_type, nil),
          else: conn

      Conn.send_resp(conn, 200, file)
    else
      {:error, :recording_not_found} ->
        {:error, :not_found, "Recording not found"}

      {:error, _reason} ->
        {:error, :not_found, "File not found"}
    end
  end

  def show(conn, _params) do
    recordings = Recording.list_all()

    conn
    |> put_resp_content_type("application/json")
    |> render("show.json", recordings: recordings)
  end

  def delete(conn, %{"recording_id" => recording_id}) do
    if Recording.exists?(recording_id) do
      Recording.delete(recording_id)
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found, "Recording not found"}
    end
  end
end
