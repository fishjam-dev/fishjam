defmodule Jellyfish.ConfigReader do
  @moduledoc false

  require Logger

  def read_port_range(env) do
    if value = System.get_env(env) do
      with [str1, str2] <- String.split(value, "-"),
           from when from in 0..65_535 <- String.to_integer(str1),
           to when to in from..65_535 and from <= to <- String.to_integer(str2) do
        {from, to}
      else
        _else ->
          raise """
          Bad #{env} environment variable value. Expected "from-to", where `from` and `to` \
          are numbers between 0 and 65535 and `from` is not bigger than `to`, got: \
          #{value}
          """
      end
    end
  end

  def read_ip(env) do
    if value = System.get_env(env) do
      value = value |> to_charlist()

      case :inet.parse_address(value) do
        {:ok, parsed_ip} ->
          parsed_ip

        _error ->
          raise """
          Bad #{env} environment variable value. Expected valid ip address, got: #{value}"
          """
      end
    end
  end

  def read_port(env) do
    if value = System.get_env(env) do
      case Integer.parse(value) do
        {port, _sufix} when port in 1..65_535 ->
          port

        _other ->
          raise """
          Bad #{env} environment variable value. Expected valid port number, got: #{value}
          """
      end
    end
  end

  def read_check_origin(env) do
    read_boolean(env, fn
      ":conn" ->
        :conn

      value ->
        String.split(value, " ")
    end)
  end

  def read_boolean(env, fallback \\ nil) do
    if value = System.get_env(env) do
      case String.downcase(value) do
        "true" ->
          true

        "false" ->
          false

        _other when is_nil(fallback) ->
          raise "Bad #{env} environment variable value. Expected true or false, got: #{value}"

        _other ->
          fallback.(value)
      end
    end
  end

  def read_dist_config() do
    dist_enabled? = read_boolean("JF_DIST_ENABLED")
    dist_strategy = System.get_env("JF_DIST_STRATEGY_NAME")
    node_name_value = System.get_env("JF_DIST_NODE_NAME")
    cookie_value = System.get_env("JF_DIST_COOKIE", "jellyfish_cookie")

    cond do
      !dist_enabled? ->
        [enabled: false, node_name: nil, cookie: nil, nodes: []]

      dist_strategy == "EPMD" ->
        nodes_value = System.get_env("JF_DIST_NODES", "")

        node_name = parse_node_name(node_name_value)
        cookie = parse_cookie(cookie_value)
        nodes = parse_nodes(nodes_value)

        if nodes == [] do
          Logger.warning("""
          JF_DIST_ENABLED has been set but JF_DIST_NODES remains unset.
          Make sure that at least one of your Jellyfish instances
          has JF_DIST_NODES set.
          """)
        end

        [
          enabled: true,
          strategy: Cluster.Strategy.Epmd,
          node_name: node_name,
          cookie: cookie,
          config: [hosts: nodes]
        ]

      dist_strategy == "DNS" ->
        node_name = parse_node_name(node_name_value)
        cookie = parse_cookie(cookie_value)

        query = parse_dns_string("JF_DIST_QUERY")
        node_basename = parse_dns_string("JF_DIST_NODE_BASENAME")
        polling_interval = parse_polling_interval()

        [
          enabled: true,
          strategy: Cluster.Strategy.DNSPoll,
          node_name: node_name,
          cookie: cookie,
          config: [
            polling_interval: polling_interval,
            query: query,
            node_basename: node_basename
          ]
        ]

      true ->
        raise """
        JF_DIST_ENABLED has been set but unknown JF_DIST_STRATEGY was provided.
        Availabile strategies are EPMD or DNS, provided strategy name was: #{dist_strategy}
        """
    end
  end

  def read_webrtc_config() do
    webrtc_used = read_boolean("JF_WEBRTC_USED")

    if webrtc_used != false do
      [
        webrtc_used: true,
        turn_ip: read_ip("JF_WEBRTC_TURN_IP") || {127, 0, 0, 1},
        turn_listen_ip: read_ip("JF_WEBRTC_TURN_LISTEN_IP") || {127, 0, 0, 1},
        turn_port_range: read_port_range("JF_WEBRTC_TURN_PORT_RANGE") || {50_000, 59_999},
        turn_tcp_port: read_port("JF_WEBRTC_TURN_TCP_PORT")
      ]
    else
      [
        webrtc_used: false,
        turn_ip: nil,
        turn_listen_ip: nil,
        turn_port_range: nil,
        turn_tcp_port: nil
      ]
    end
  end

  defp parse_node_name(node_name) do
    unless node_name do
      raise "JF_DIST_ENABLED has been set but JF_DIST_NODE_NAME remains unset."
    end

    String.to_atom(node_name)
  end

  defp parse_cookie(cookie_value), do: String.to_atom(cookie_value)

  defp parse_nodes(nodes_value) do
    nodes_value
    |> String.split(" ", trim: true)
    |> Enum.map(&String.to_atom(&1))
  end

  defp parse_dns_string(env_name) do
    env = System.get_env(env_name)

    unless env do
      raise "DNS strategy has been set but #{env_name} remains unset."
    end

    env
  end

  defp parse_polling_interval() do
    env_value = System.get_env("JF_DIST_POLLING_INTERVAL", "5000")

    polling_interval =
      try do
        String.to_integer(env_value)
      rescue
        ArgumentError ->
          reraise(
            "Error during parsing `JF_DIST_POLLING_INTERVAL`. Provided value should be integer and was: #{env_value}",
            __STACKTRACE__
          )
      end

    if polling_interval <= 0 do
      raise "`JF_DIST_POLLING_INTERVAL` must be positivie integer. Provided value was: #{polling_interval}"
    else
      polling_interval
    end
  end
end
