defmodule JellyfishWeb.ApiSpec.Component.RTSP do
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
      maxReconnectAttempts: %Schema{
        type: :integer,
        description: "How many times the component will attempt to reconnect before hibernating",
        minimum: 0,
        default: 3
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
