import Config

config :fishjam,
  ip: {127, 0, 0, 1},
  port: 4002,
  server_api_token: "development",
  webrtc_metrics_scrape_interval: 50,
  room_metrics_scrape_interval: 1,
  feature_flags: [
    # TODO: Enable this flag here once we start using it in production
    custom_room_name_disabled: false
  ],
  test_routes: true

config :fishjam, FishjamWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :ex_aws, :http_client, ExAws.Request.HttpMock

config :ex_aws, :awscli_auth_adapter, Fishjam.Adapter
