defmodule FishjamWeb.ApiSpec.HealthReport do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule NodeStatus do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NodeStatus",
      description: "Informs about the status of node",
      type: :object,
      properties: %{
        status: %Schema{
          type: :string,
          enum: [
            "UP",
            "DOWN"
          ],
          description: "Informs about the status of Fishjam or a specific service"
        },
        version: %Schema{type: :string, description: "Version of Fishjam"},
        uptime: %Schema{type: :integer, description: "Uptime of Fishjam (in seconds)"},
        nodeName: %Schema{type: :string, description: "Name of the node"},
        gitCommit: %Schema{type: :string, description: "Commit hash of the build"}
      },
      required: [:status, :version, :uptime, :nodeName, :gitCommit]
    })
  end

  OpenApiSpex.schema(%{
    title: "HealthReport",
    description: "Describes overall Fishjam health",
    type: :object,
    properties: %{
      localStatus: NodeStatus,
      nodesInCluster: %Schema{type: :integer, description: "Number of nodes in cluster"},
      distributionEnabled: %Schema{
        type: :boolean,
        description: "Cluster distribution enabled/disabled"
      },
      nodesStatus: %Schema{
        type: :array,
        items: NodeStatus,
        description: "Status of each node in cluster"
      }
    },
    required: [:localStatus, :nodesInCluster, :distributionEnabled, :nodesStatus]
  })
end
