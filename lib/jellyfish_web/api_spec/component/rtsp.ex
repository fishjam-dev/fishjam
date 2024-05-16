defmodule FishjamWeb.ApiSpec.Component.RTSP do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Properties do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentPropertiesRTSP",
      description: "Properties specific to the RTSP component",
      type: :object,
      properties: %{
        sourceUri: %Schema{
          type: :string,
          description: "URI of RTSP source stream"
        },
        rtpPort: %Schema{
          type: :integer,
          description: "Local port RTP stream will be received at"
        },
        reconnectDelay: %Schema{
          type: :integer,
          description: "Delay (in ms) between successive reconnect attempts"
        },
        keepAliveInterval: %Schema{
          type: :integer,
          description:
            "Interval (in ms) in which keep-alive RTSP messages will be sent to the remote stream source"
        },
        pierceNat: %Schema{
          type: :boolean,
          description:
            "Whether to attempt to create client-side NAT binding by sending an empty datagram from client to source, after the completion of RTSP setup"
        }
      },
      required: [:sourceUri, :rtpPort, :reconnectDelay, :keepAliveInterval, :pierceNat]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentOptionsRTSP",
      description: "Options specific to the RTSP component",
      type: :object,
      properties: %{
        sourceUri: %Schema{
          type: :string,
          description: "URI of RTSP source stream",
          example: "rtsp://localhost:554/stream"
        },
        rtpPort: %Schema{
          type: :integer,
          description: "Local port RTP stream will be received at",
          minimum: 1,
          maximum: 65_535,
          default: 20_000
        },
        reconnectDelay: %Schema{
          type: :integer,
          description: "Delay (in ms) between successive reconnect attempts",
          minimum: 0,
          default: 15_000
        },
        keepAliveInterval: %Schema{
          type: :integer,
          description:
            "Interval (in ms) in which keep-alive RTSP messages will be sent to the remote stream source",
          minimum: 0,
          default: 15_000
        },
        pierceNat: %Schema{
          type: :boolean,
          description:
            "Whether to attempt to create client-side NAT binding by sending an empty datagram from client to source, after the completion of RTSP setup",
          default: true
        }
      },
      required: [:sourceUri]
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentRTSP",
    description: "Describes the RTSP component",
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
