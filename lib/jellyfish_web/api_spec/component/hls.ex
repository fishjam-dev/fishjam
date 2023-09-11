defmodule JellyfishWeb.ApiSpec.Component.HLS do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Metadata do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentMetadataHLS",
      description: "Metadata specific to the HLS component",
      type: :object,
      properties: %{
        playable: %Schema{
          type: :boolean,
          description: "Whether the generated HLS playlist is playable"
        },
        lowLatency: %Schema{
          type: :boolean,
          description: "Whether the component uses LL-HLS"
        }
      },
      required: [:playable, :lowLatency]
    })
  end

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
