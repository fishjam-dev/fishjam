defmodule JellyfishWeb.HealthcheckJSON do
  @moduledoc false

  def show(%{report: report}) do
    %{data: data(report)}
  end

  def data(%{status: status, distribution: distribution} = report) do
    report
    |> Map.take([:uptime, :version, :git_commit])
    |> Map.merge(%{
      status: status_str(status),
      distribution: %{
        enabled: distribution.enabled,
        nodeStatus: status_str(distribution.node_status),
        nodesInCluster: distribution.nodes_in_cluster
      }
    })
  end

  defp status_str(:up), do: "UP"
  defp status_str(:down), do: "DOWN"
end
