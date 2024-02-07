import Config

config :jellyfish,
  ip: {127, 0, 0, 1},
  port: 4002,
  server_api_token: "development",
  webrtc_metrics_scrape_interval: 50,
  peer_metrics_scrape_interval: 1

config :jellyfish, JellyfishWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :ex_aws, :http_client, ExAws.Request.HttpMock
