import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
defmodule ConfigParser do
  def parse_integrated_turn_ip(addr) do
    addr = addr |> to_charlist()

    case :inet.parse_address(addr) do
      {:ok, parsed_ip} ->
        parsed_ip

      _error ->
        with {:ok, parsed_ip} <- :inet.getaddr(addr, :inet) do
          parsed_ip
        else
          _error ->
            raise("""
            Bad integrated TURN address. Expected IPv4 or a valid hostname, got: \
            #{inspect(addr)}
            """)
        end
    end
  end

  def parse_integrated_turn_port_range(range) do
    with [str1, str2] <- String.split(range, "-"),
         from when from in 0..65_535 <- String.to_integer(str1),
         to when to in from..65_535 and from <= to <- String.to_integer(str2) do
      {from, to}
    else
      _else ->
        raise("""
        Bad INTEGRATED_TURN_PORT_RANGE environment variable value. Expected "from-to", where `from` and `to` \
        are numbers between 0 and 65535 and `from` is not bigger than `to`, got: \
        #{inspect(range)}
        """)
    end
  end

  def parse_port_number(nil, _var_name), do: nil

  def parse_port_number(var_value, var_name) do
    with {port, _sufix} when port in 1..65535 <- Integer.parse(var_value) do
      port
    else
      _var ->
        raise(
          "Bad #{var_name} environment variable value. Expected valid port number, got: #{inspect(var_value)}"
        )
    end
  end

  def get_env!(env_key) do
    case System.get_env(env_key) do
      nil -> raise("Environmental variable #{env_key} was not set properly")
      env_val -> env_val
    end
  end
end

hosts =
  System.get_env("NODES", "")
  |> String.split(" ")
  |> Enum.reject(&(&1 == ""))
  |> Enum.map(&String.to_atom(&1))

unless Enum.empty?(hosts) do
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
  case System.get_env("VIRTUAL_HOST") do
    nil when prod? -> raise "Unset VIRTUAL_HOST environment variable"
    nil -> "localhost"
    other -> other
  end

port =
  case System.get_env("PORT") do
    nil when prod? -> raise "Unset PORT environment variable"
    nil -> 5002
    other -> String.to_integer(other)
  end

jellyfish_address = System.get_env("JELLYFISH_ADDRESS") || "#{host}:#{port}"

config :jellyfish,
  webrtc_used: String.downcase(System.get_env("WEBRTC_USED", "true")) not in ["false", "f", "0"],
  integrated_turn_ip:
    System.get_env("INTEGRATED_TURN_IP", "127.0.0.1") |> ConfigParser.parse_integrated_turn_ip(),
  integrated_turn_listen_ip:
    System.get_env("INTEGRATED_TURN_LISTEN_IP", "127.0.0.1")
    |> ConfigParser.parse_integrated_turn_ip(),
  integrated_turn_port_range:
    System.get_env("INTEGRATED_TURN_PORT_RANGE", "50000-59999")
    |> ConfigParser.parse_integrated_turn_port_range(),
  integrated_turn_tcp_port:
    System.get_env("INTEGRATED_TURN_TCP_PORT")
    |> ConfigParser.parse_port_number("INTEGRATED_TURN_TCP_PORT"),
  jwt_max_age: 24 * 3600,
  output_base_path: System.get_env("OUTPUT_BASE_PATH", "jellyfish_output") |> Path.expand(),
  address: jellyfish_address

config :opentelemetry, traces_exporter: :none

if prod? do
  token =
    System.fetch_env!("SERVER_API_TOKEN") ||
      raise """
      environment variable SERVER_API_TOKEN is missing.
      SERVER_API_TOKEN is used for HTTP requests and
      server WebSocket authorization.
      """

  config :jellyfish, server_api_token: token

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  check_origin? = System.get_env("CHECK_ORIGIN", "true") == "true"

  config :jellyfish, JellyfishWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: check_origin?,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :jellyfish, JellyfishWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :jellyfish, JellyfishWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
