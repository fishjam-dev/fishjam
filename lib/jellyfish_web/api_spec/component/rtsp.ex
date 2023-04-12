defmodule JellyfishWeb.ApiSpec.Component.RTSP do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ComponentOptionsRTSP",
    description: "Options specific to the RTSP component",
    type: :object,
    properties: %{
      source_uri: %Schema{
        type: :string,
        description: "URI of RTSP source stream",
        example: "rtsp://localhost:554/stream"
      },
      rtp_port: %Schema{
        type: :integer,
        description: "Local port RTP stream will be received at",
        minimum: 1,
        maximum: 65_535,
        default: 20_000
      },
      max_reconnect_attempts: %Schema{
        type: :integer,
        description: "How many times the component will attempt to reconnect before hibernating",
        minimum: 0,
        default: 3
      },
      reconnect_delay: %Schema{
        type: :integer,
        description: "Delay (in ms) between successive reconnect attempts",
        minimum: 0,
        default: 15_000
      },
      keep_alive_interval: %Schema{
        type: :integer,
        description:
          "Interval (in ms) in which keep-alive RTSP messages will be sent to the remote stream source",
        minimum: 0,
        default: 15_000
      },
      pierce_nat: %Schema{
        type: :boolean,
        description:
          "Whether to attempt to create client-side NAT binding by sending an empty datagram from client to source, after the completion of RTSP setup",
        default: true
      }
    },
    required: [:source_uri]
  })
end
