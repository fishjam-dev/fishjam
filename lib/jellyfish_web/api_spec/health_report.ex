defmodule FishjamWeb.ApiSpec.HealthReport do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Status do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthReportStatus",
      description: "Informs about the status of Fishjam or a specific service",
      type: :string,
      enum: ["UP", "DOWN"],
      example: "UP"
    })
  end

  defmodule Distribution do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthReportDistribution",
      description: "Informs about the status of Fishjam distribution",
      type: :object,
      properties: %{
        enabled: %Schema{
          type: :boolean,
          description: "Whether distribution is enabled on this Fishjam"
        },
        nodeStatus: Status,
        nodesInCluster: %Schema{
          type: :integer,
          description:
            "Amount of nodes (including this Fishjam's node) in the distribution cluster"
        }
      },
      required: [:nodeStatus, :nodesInCluster]
    })
  end

  OpenApiSpex.schema(%{
    title: "HealthReport",
    description: "Describes overall Fishjam health",
    type: :object,
    properties: %{
      status: Status,
      uptime: %Schema{type: :integer, description: "Uptime of Fishjam (in seconds)"},
      distribution: Distribution,
      version: %Schema{type: :string, description: "Version of Fishjam"},
      gitCommit: %Schema{type: :string, description: "Commit hash of the build"}
    },
    required: [:status, :uptime, :distribution, :version, :gitCommit]
  })
end
