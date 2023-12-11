import Config

config :jellyfish, ip: {127, 0, 0, 1}, port: 4002, server_api_token: "development"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jellyfish, JellyfishWeb.Endpoint, server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
