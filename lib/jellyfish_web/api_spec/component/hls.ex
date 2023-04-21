defmodule JellyfishWeb.ApiSpec.Component.HLS do
  @moduledoc false

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ComponentOptionsHLS",
    description: "Options specific to the HLS component",
    type: :object,
    properties: %{},
    required: []
  })
end
