import Config

config :jellyfish, JellyfishWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: JellyfishWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jellyfish.PubSub,
  live_view: [signing_salt: "/Lo03qJT"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :room_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
