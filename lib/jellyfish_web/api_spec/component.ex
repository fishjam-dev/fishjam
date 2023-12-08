defmodule JellyfishWeb.ApiSpec.Component do
  @moduledoc false

  require OpenApiSpex

  alias JellyfishWeb.ApiSpec.Component.{File, HLS, RTSP}

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
        RTSP.Options,
        File.Options
      ]
    })
  end

  OpenApiSpex.schema(%{
    title: "Component",
    description: "Describes component",
    type: :object,
    oneOf: [
      HLS,
      RTSP,
      File
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "type",
      mapping: %{
        "hls" => HLS,
        "rtsp" => RTSP,
        "file" => File
      }
    }
  })
end
