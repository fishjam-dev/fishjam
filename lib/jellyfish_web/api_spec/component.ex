defmodule FishjamWeb.ApiSpec.Component do
  @moduledoc false

  require OpenApiSpex

  alias FishjamWeb.ApiSpec.Component.{File, HLS, Recording, RTSP, SIP}

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
        File.Options,
        SIP.Options,
        Recording.Options
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
      File,
      SIP,
      Recording
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "type",
      mapping: %{
        "hls" => HLS,
        "rtsp" => RTSP,
        "file" => File,
        "sip" => SIP,
        "recording" => Recording
      }
    }
  })
end
