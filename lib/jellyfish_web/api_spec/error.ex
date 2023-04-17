defmodule JellyfishWeb.ApiSpec.Error do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    description: "Error message",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :string,
        description: "Error details",
        example: "Token has expired"
      }
    },
    required: [:errors]
  })
end
