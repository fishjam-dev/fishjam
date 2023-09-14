defmodule JellyfishWeb.ApiSpec.Component do
  @moduledoc false

  require OpenApiSpex

  alias JellyfishWeb.ApiSpec.Component.{HLS, RTSP}

  defmodule ID do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentID",
      description: "Assigned component id",
      type: :string,
      example: "component-1"
    })
  end

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
        HLS.Options,
        RTSP.Options
      ]
    })
  end

  # defmodule Metadata do
  #   @moduledoc false

  #   require OpenApiSpex

  #   OpenApiSpex.schema(%{
  #     title: "ComponentMetadata",
  #     description: "Component-specific metadata",
  #     type: :object,
  #     oneOf: [
  #       HLS.Metadata,
  #       RTSP.Metadata
  #     ]
  #   })
  # end

  OpenApiSpex.schema(%{
    title: "Component",
    description: "Describes component",
    type: :object,
    oneOf: [
      HLS,
      RTSP
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "type",
      mapping: %{
        "hls" => HLS,
        "rtsp" => RTSP
      }
    }
    # properties: %{
    #   id: %Schema{type: :string, description: "Assigned component id", example: "component-1"},
    #   type: Type,
    #   metadata: Metadata
    # },
    # required: [:id, :type, :metadata]
  })
end
