import Config

config :fishjam, ip: {127, 0, 0, 1}, port: 4002, server_api_token: "development"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fishjam, FishjamWeb.Endpoint, server: false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
