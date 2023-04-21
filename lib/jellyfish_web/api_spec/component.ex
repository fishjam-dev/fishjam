defmodule JellyfishWeb.ApiSpec.Component do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias JellyfishWeb.ApiSpec.Component.{HLS, RTSP}

  defmodule Type do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentType",
      description: "Component type",
      type: :string,
      example: "hls"
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentOptions",
      description: "Component-specific options",
      type: :object,
      oneOf: [
        HLS,
        RTSP
      ]
    })
  end

  OpenApiSpex.schema(%{
    title: "Component",
    description: "Describes component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component id", example: "component-1"},
      type: Type
    },
    required: [:id, :type]
  })
end
