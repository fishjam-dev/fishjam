defmodule JellyfishWeb.ApiSpec.HealthReport do
  @moduledoc false

  require OpenApiSpex

  defmodule Status do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthReportStatus",
      description: "Informs about the status of Jellyfish",
      type: :string,
      enum: ["UP", "DOWN"],
      example: "UP"
    })
  end

  OpenApiSpex.schema(%{
    title: "HealthReport",
    description: "Describes overall Jellyfish health",
    type: :object,
    properties: %{
      status: Status
    },
    required: [:status]
  })
end
