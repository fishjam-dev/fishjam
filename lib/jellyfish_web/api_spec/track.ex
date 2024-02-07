defmodule JellyfishWeb.ApiSpec.Track do
  @moduledoc false
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
      metadata: %Schema{
        nullable: true
      }
    }
  })
end
