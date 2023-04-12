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
      rtp_port: %Schema{type: :integer, description: "", minimum: 1, maximum: 65_535},
      max_reconnect_attempts: %Schema{type: :integer, description: "", minimum: 0},
      reconnect_delay: %Schema{type: :integer, description: "", minimum: 0},
      keep_alive_interval: %Schema{type: :integer, description: "", minimum: 0},
      pierce_nat: %Schema{type: :boolean, description: ""}
    },
    required: [:source_uri]
  })
end
