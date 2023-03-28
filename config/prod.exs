import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

# Do not print debug messages in production
config :logger, level: :info

# run the server automatically when using prod release
config :jellyfish, JellyfishWeb.Endpoint, server: true

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
