defmodule FishjamWeb.HealthcheckController do
  use FishjamWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FishjamWeb.ApiSpec

  action_fallback FishjamWeb.FallbackController

  tags [:health]

  security(%{"authorization" => []})

  operation :show,
    operation_id: "healthcheck",
    summary: "Describes the health of Fishjam",
    responses: [
      ok: ApiSpec.data("Healthy", ApiSpec.HealthcheckResponse),
      unauthorized: ApiSpec.error("Unauthorized")
    ]

  def show(conn, _params) do
    report = get_health_report()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{data: report}))
  end

  defp get_health_report() do
    %{
      localStatus: get_health_status(),
      distributionEnabled: Application.fetch_env!(:fishjam, :dist_config)[:enabled],
      nodesInCluster: length([Node.self() | Node.list()]),
      nodesStatus: Fishjam.RPCClient.multicall(__MODULE__, :get_health_status, [])
    }
  end

  def get_health_status do
    %{
      status: "UP",
      nodeName: Node.self(),
      uptime: get_uptime(),
      version: Fishjam.version(),
      gitCommit: Application.get_env(:fishjam, :git_commit)
    }
  end

  defp get_uptime() do
    System.monotonic_time(:second) - Application.fetch_env!(:fishjam, :start_time)
  end
end
