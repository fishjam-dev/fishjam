defmodule FishjamWeb.ApiSpec.Component.HLS do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Properties do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentPropertiesHLS",
      description: "Properties specific to the HLS component",
      type: :object,
      properties: %{
        playable: %Schema{
          type: :boolean,
          description: "Whether the generated HLS playlist is playable"
        },
        lowLatency: %Schema{
          type: :boolean,
          description: "Whether the component uses LL-HLS"
        },
        targetWindowDuration: %Schema{
          type: :integer,
          description: "Duration of stream available for viewer",
          nullable: true
        },
        persistent: %Schema{
          type: :boolean,
          description: "Whether the video is stored after end of stream"
        },
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the HLS component should subscribe to tracks automatically or manually",
          enum: ["auto", "manual"]
        }
      },
      required: [:playable, :lowLatency, :persistent, :targetWindowDuration, :subscribeMode]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema
    alias FishjamWeb.ApiSpec.Component.HLS.S3

    OpenApiSpex.schema(%{
      title: "ComponentOptionsHLS",
      description: "Options specific to the HLS component",
      type: :object,
      properties: %{
        lowLatency: %Schema{
          type: :boolean,
          description: "Whether the component should use LL-HLS",
          default: false
        },
        targetWindowDuration: %Schema{
          type: :integer,
          description: "Duration of stream available for viewer",
          nullable: true
        },
        persistent: %Schema{
          type: :boolean,
          description: "Whether the video is stored after end of stream",
          default: false
        },
        s3: S3.schema(),
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the HLS component should subscribe to tracks automatically or manually.",
          enum: ["auto", "manual"],
          default: "auto"
        }
      },
      required: []
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentHLS",
    description: "Describes the HLS component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      # FIXME: due to cyclic imports, we can't use ApiSpec.Component.Type here
      type: %Schema{type: :string, description: "Component type", example: "hls"},
      properties: Properties,
      tracks: %Schema{
        type: :array,
        items: FishjamWeb.ApiSpec.Track,
        description: "List of all component's tracks"
      }
    },
    required: [:id, :type, :properties, :tracks]
  })
end
