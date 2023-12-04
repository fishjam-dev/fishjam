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
  jwt_max_age: 24 * 3600,
  media_files_path:
    System.get_env("JF_MEDIA_FILES_PATH", "jellyfish_media_files") |> Path.expand(),
  address: "#{host}",
  metrics_ip: ConfigReader.read_ip("JF_METRICS_IP") || {127, 0, 0, 1},
  metrics_port: ConfigReader.read_port("JF_METRICS_PORT") || 9568,
  dist_config: ConfigReader.read_dist_config(),
  webrtc_config: ConfigReader.read_webrtc_config()

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

check_origin = ConfigReader.read_check_origin("JF_CHECK_ORIGIN")

if check_origin != nil do
  config :jellyfish, JellyfishWeb.Endpoint, check_origin: check_origin
end

if prod? do
  config :jellyfish, JellyfishWeb.Endpoint, url: [scheme: "https"]
end
