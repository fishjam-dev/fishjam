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

prod? = config_env() == :prod

ip =
  ConfigReader.read_ip("JF_IP") ||
    Application.get_env(:jellyfish, JellyfishWeb.Endpoint)[:http][:ip]

port =
  ConfigReader.read_port("JF_PORT") ||
    Application.get_env(:jellyfish, JellyfishWeb.Endpoint)[:http][:port]

host =
  case System.get_env("JF_HOST") do
    nil -> "#{:inet.ntoa(ip)}:#{port}"
    other -> other
  end

{host_name, host_port} =
  case String.split(host, ":") do
    [host_name, host_port] -> {host_name, String.to_integer(host_port)}
    _ -> {host, 443}
  end

config :jellyfish,
  webrtc_used: ConfigReader.read_boolean("JF_WEBRTC_USED") || true,
  integrated_turn_ip: ConfigReader.read_ip("JF_INTEGRATED_TURN_IP") || {127, 0, 0, 1},
  integrated_turn_listen_ip:
    ConfigReader.read_ip("JF_INTEGRATED_TURN_LISTEN_IP") || {127, 0, 0, 1},
  integrated_turn_port_range:
    ConfigReader.read_port_range("JF_INTEGRATED_TURN_PORT_RANGE") || {50_000, 59_999},
  integrated_turn_tcp_port: ConfigReader.read_port("JF_INTEGRATED_TURN_TCP_PORT"),
  jwt_max_age: 24 * 3600,
  output_base_path: System.get_env("JF_OUTPUT_BASE_PATH", "jellyfish_output") |> Path.expand(),
  address: "#{host}",
  metrics_ip: ConfigReader.read_ip("JF_METRICS_IP") || {127, 0, 0, 1},
  metrics_port: ConfigReader.read_port("JF_METRICS_PORT") || 9568,
  dist_config: ConfigReader.read_dist_config()

case System.get_env("JF_SERVER_API_TOKEN") do
  nil when prod? == true ->
    raise """
    environment variable JF_SERVER_API_TOKEN is missing.
    JF_SERVER_API_TOKEN is used for HTTP requests and
    server WebSocket authorization.
    """

  nil ->
    :ok

  token ->
    config :jellyfish, server_api_token: token
end

config :jellyfish, JellyfishWeb.Endpoint,
  secret_key_base:
    System.get_env("JF_SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(48)),
  http: [ip: ip, port: port],
  url: [host: host_name, port: host_port]

if check_origin = ConfigReader.read_boolean("JF_CHECK_ORIGIN") do
  config :jellyfish, JellyfishWeb.Endpoint, check_origin: check_origin
end

if prod? do
  config :jellyfish, JellyfishWeb.Endpoint, url: [scheme: "https"]
end
