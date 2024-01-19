defmodule JellyfishWeb.HealthcheckController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias JellyfishWeb.ApiSpec

  action_fallback JellyfishWeb.FallbackController

  operation :show,
    operation_id: "healthcheck",
    summary: "Describes the health of Jellyfish",
    responses: [
      ok: ApiSpec.data("Healthy", ApiSpec.HealthcheckResponse),
      internal_server_error: ApiSpec.data("Unhealthy", ApiSpec.HealthcheckResponse)
    ]

  def show(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> render("show.json", status: "UP")
  end
end
