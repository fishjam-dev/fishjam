defmodule JellyfishWeb.ApiSpec.Component.HLS do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ComponentOptionsHLS",
    description: "Options specific to the HLS component",
    type: :object,
    properties: %{
      lowLatency: %Schema{
        type: :boolean,
        description: "Whether the component should use LL-HLS",
        default: false
      }
    },
    required: []
  })
end
