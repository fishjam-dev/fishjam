defmodule JellyfishWeb.ApiSpec.Track do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Track",
    description: "Describes media track of a Peer or Component",
    type: :object,
    properties: %{
      id: %Schema{
        type: :string
      },
      type: %Schema{
        type: :string,
        enum: ["audio", "video"]
      },
      encoding: %Schema{
        type: :string,
        enum: ["H264", "VP8", "OPUS"]
      },
      metadata: %Schema{
        type: :string,
        nullable: true
      }
    }
  })
end
