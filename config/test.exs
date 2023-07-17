import Config

config :jellyfish,
  server_api_token: "development",
  metrics_scrape_interval: 50

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jellyfish, JellyfishWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DtVd7qfpae0tk5zRgAM75hOaCc+phk38gDFVvLPyqVN/vvVg0EPmksTSm5JcyjoJ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
