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

  def read_dist_config() do
    dist_enabled? = read_boolean("JF_DIST_ENABLED")
    dist_strategy = System.get_env("JF_DIST_STRATEGY_NAME")
    node_name_value = System.get_env("JF_DIST_NODE_NAME")
    cookie_value = System.get_env("JF_DIST_COOKIE", "jellyfish_cookie")

    cond do
      is_nil(dist_enabled?) or not dist_enabled? ->
        [enabled: false, strategy: nil, node_name: nil, cookie: nil, strategy_config: nil]

      dist_strategy == "NODES_LIST" or is_nil(dist_strategy) ->
        nodes_value = System.get_env("JF_DIST_NODES", "")

        unless node_name_value do
          raise "JF_DIST_ENABLED has been set but JF_DIST_NODE_NAME remains unset."
        end

        node_name = parse_node_name(node_name_value)
        cookie = parse_cookie(cookie_value)
        nodes = parse_nodes(nodes_value)

        if nodes == [] do
          Logger.warning("""
          NODES_LIST strategy requires JF_DIST_NODES to be set
          by at least one Jellyfish instace. This instance has JF_DIST_NODES unset.
          """)
        end

        [
          enabled: true,
          strategy: Cluster.Strategy.Epmd,
          node_name: node_name,
          cookie: cookie,
          strategy_config: [hosts: nodes]
        ]

      dist_strategy == "DNS" ->
        do_read_dns_config(node_name_value, cookie_value)

      true ->
        raise """
        JF_DIST_ENABLED has been set but unknown JF_DIST_STRATEGY was provided.
        Availabile strategies are EPMD or DNS, provided strategy name was: "#{dist_strategy}"
        """
    end
  end

  defp do_read_dns_config(node_name_value, cookie_value) do
    unless node_name_value do
      raise "JF_DIST_ENABLED has been set but JF_DIST_NODE_NAME remains unset."
    end

    node_name = parse_node_name(node_name_value)
    cookie = parse_cookie(cookie_value)

    query_value = System.get_env("JF_DIST_QUERY")

    unless query_value do
      raise "JF_DIST_QUERY is required by DNS strategy"
    end

    [node_basename, _ip_addres_or_fqdn | []] = String.split(node_name_value, "@")

    polling_interval = parse_polling_interval()

    [
      enabled: true,
      strategy: Cluster.Strategy.DNSPoll,
      node_name: node_name,
      cookie: cookie,
      strategy_config: [
        polling_interval: polling_interval,
        query: query_value,
        node_basename: node_basename
      ]
    ]
  end

  defp parse_node_name(node_name) do
    case String.split(node_name, "@") do
      [_node_basename, _ip_addres_or_fqdn | []] ->
        String.to_atom(node_name)

      _other ->
        raise "JF_DIST_NODE_NAME has to be in form of <nodename>@<hostname>. Got: #{node_name}"
    end
  end

  defp parse_cookie(cookie_value), do: String.to_atom(cookie_value)

  defp parse_nodes(nodes_value) do
    nodes_value
    |> String.split(" ", trim: true)
    |> Enum.map(&String.to_atom(&1))
  end

  defp parse_polling_interval() do
    env_value = System.get_env("JF_DIST_POLLING_INTERVAL", "5000")

    case Integer.parse(env_value) do
      {polling_interval, ""} when polling_interval > 0 ->
        polling_interval

      _other ->
        raise "`JF_DIST_POLLING_INTERVAL` must be a positivie integer. Got: #{env_value}"
    end
  end
end
