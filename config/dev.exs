import Config

# Binding to loopback ipv4 address prevents access from other machines.
# Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
config :fishjam,
  ip: {127, 0, 0, 1},
  port: 5002,
  server_api_token: "development",
  dev_routes: true

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :fishjam, FishjamWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: []

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
