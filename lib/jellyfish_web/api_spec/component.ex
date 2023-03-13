defmodule JellyfishWeb.ApiSpec.Component do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

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
      example: %{
        output_path: "/hls-output"
      }
    })
  end

  OpenApiSpex.schema(%{
    title: "Component",
    description: "Describes component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component id", example: "component-1"},
      type: Type
    }
  })
end
