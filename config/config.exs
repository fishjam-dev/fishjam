import Config

config :jellyfish, JellyfishWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: JellyfishWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jellyfish.PubSub,
  live_view: [signing_salt: "/Lo03qJT"]

config :jellyfish, metrics_scrape_interval: 1000

config :membrane_telemetry_metrics, enabled: true
config :membrane_opentelemetry, enabled: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :room_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
