import Config

alias Jellyfish.ConfigReader

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
config :ex_dtls, impl: :nif
config :opentelemetry, traces_exporter: :none

hosts = ConfigReader.read_nodes("NODES")

if hosts do
  config :libcluster,
    topologies: [
      epmd_cluster: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: hosts]
      ]
    ]
end

prod? = config_env() == :prod

host =
  case System.get_env("HOST") do
    nil when prod? -> raise "Unset HOST environment variable"
    nil -> "localhost"
    other -> other
  end

port =
  ConfigReader.read_port("PORT") ||
    Application.get_env(:jellyfish, JellyfishWeb.Endpoint)[:http][:port]

config :jellyfish,
  webrtc_used: ConfigReader.read_boolean("WEBRTC_USED") || true,
  integrated_turn_ip: ConfigReader.read_ip("INTEGRATED_TURN_IP") || {127, 0, 0, 1},
  integrated_turn_listen_ip: ConfigReader.read_ip("INTEGRATED_TURN_LISTEN_IP") || {127, 0, 0, 1},
  integrated_turn_port_range:
    ConfigReader.read_port_range("INTEGRATED_TURN_PORT_RANGE") || {50_000, 59_999},
  integrated_turn_tcp_port: ConfigReader.read_port("INTEGRATED_TURN_TCP_PORT"),
  jwt_max_age: 24 * 3600,
  output_base_path: System.get_env("OUTPUT_BASE_PATH", "jellyfish_output") |> Path.expand(),
  address: System.get_env("JELLYFISH_ADDRESS") || "#{host}:#{port}",
  metrics_ip: ConfigReader.read_ip("METRICS_IP") || {127, 0, 0, 1},
  metrics_port: ConfigReader.read_port("METRICS_PORT") || 9568

config :jellyfish, JellyfishWeb.Endpoint,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(48)),
  http: [port: port]

if check_origin = ConfigReader.read_boolean("CHECK_ORIGIN") do
  config :jellyfish, JellyfishWeb.Endpoint, check_origin: check_origin
end

case System.get_env("SERVER_API_TOKEN") do
  nil when prod? == true ->
    raise """
    environment variable SERVER_API_TOKEN is missing.
    SERVER_API_TOKEN is used for HTTP requests and
    server WebSocket authorization.
    """

  nil ->
    :ok

  token ->
    config :jellyfish, server_api_token: token
end

if prod? do
  config :jellyfish, JellyfishWeb.Endpoint, url: [host: host, port: 443, scheme: "https"]
end
