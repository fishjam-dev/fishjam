defmodule FishjamWeb.UploadController do
  use FishjamWeb, :controller
  use OpenApiSpex.ControllerSpecs

  # alias Fishjam.Room
  # alias Fishjam.RoomService
  # alias FishjamWeb.ApiSpec
  # alias OpenApiSpex.Response

  action_fallback FishjamWeb.FallbackController

  # tags []

  security(%{"authorization" => []})

  # operation :create,
  #   # operation_id: "subscribe_to",
  #   # summary: "Subscribe component to the tracks of peers or components",
  #   parameters: [
  #     # file: [in: :path, description: "Room ID", type: :string],
  #   ],
  #   # request_body: {"Subscribe configuration", "application/json", ApiSpec.Subscription.Origins},
  #   responses: [
  #     # created: %Response{description: "Tracks succesfully added."},
  #     # bad_request: ApiSpec.error("Invalid request structure"),
  #     # not_found: ApiSpec.error("Room doesn't exist"),
  #     # unauthorized: ApiSpec.error("Unauthorized")
  #   ]

  def create(conn, %{"data" => upload}) do
    IO.inspect(upload, label: :file_upload)

    File.cp(upload.path, "./fishjam_resources/file_component_sources/#{upload.filename}")

    send_resp(conn, :created, "Successfully uploaded file #{upload.filename}")
  end
end
