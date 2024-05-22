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
    |> render("show.json", report: report)
  end

  defp get_health_report() do
    %{
      status: :up,
      uptime: get_uptime(),
      distribution: get_distribution_report(),
      version: Fishjam.version(),
      gitCommit: Application.get_env(:fishjam, :git_commit)
    }
  end

  defp get_uptime() do
    System.monotonic_time(:second) - Application.fetch_env!(:fishjam, :start_time)
  end

  defp get_distribution_report() do
    alive? = Node.alive?()
    visible_nodes = Node.list() |> length()

    %{
      enabled: Application.fetch_env!(:fishjam, :dist_config)[:enabled],
      node_status: if(alive?, do: :up, else: :down),
      nodes_in_cluster: visible_nodes + if(alive?, do: 1, else: 0)
    }
  end
end
