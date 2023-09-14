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

  defmodule Options do
    @moduledoc false

    require OpenApiSpex

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

  OpenApiSpex.schema(%{
    title: "ComponentHLS",
    description: "Describes HLS component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      type: %Schema{type: :string, description: "Component type", example: "hls"},
      metadata: Metadata
    },
    required: [:id, :type, :metadata]
  })
end
