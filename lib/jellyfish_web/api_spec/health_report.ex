defmodule JellyfishWeb.ApiSpec.HealthReport do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Status do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthReportStatus",
      description: "Informs about the status of Jellyfish or a specific service",
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
      description: "Informs about the status of Jellyfish distribution",
      type: :object,
      properties: %{
        enabled: %Schema{
          type: :boolean,
          description: "Whether distribution is enabled on this Jellyfish"
        },
        nodeStatus: Status,
        nodesInCluster: %Schema{
          type: :integer,
          description:
            "Amount of nodes (including this Jellyfish's node) in the distribution cluster"
        }
      },
      required: [:nodeStatus, :nodesInCluster]
    })
  end

  OpenApiSpex.schema(%{
    title: "HealthReport",
    description: "Describes overall Jellyfish health",
    type: :object,
    properties: %{
      status: Status,
      uptime: %Schema{type: :integer, description: "Uptime of Jellyfish (in seconds)"},
      distribution: Distribution
    },
    required: [:status, :uptime, :distribution]
  })
end
