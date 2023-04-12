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

  [HLS, RTSP]
  |> Enum.map(fn module ->
    type_str = Module.split(module) |> List.last()
    config_module = Module.concat(module, Config)

    defmodule config_module do
      require OpenApiSpex

      OpenApiSpex.schema(%{
        title: "ComponentConfig#{type_str}",
        description: "Config specific to the #{type_str} component",
        type: :object,
        properties: %{
          type: Type,
          options: module
        },
        required: [:type, :options]
      })
    end
  end)

  defmodule Config do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentConfig",
      description: "Component-specific config",
      type: :object,
      discriminator: %OpenApiSpex.Discriminator{
        propertyName: "type",
        mapping: %{
          "hls" => HLS.Config,
          "rtsp" => RTSP.Config
        }
      },
      oneOf: [
        HLS.Config,
        RTSP.Config
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
