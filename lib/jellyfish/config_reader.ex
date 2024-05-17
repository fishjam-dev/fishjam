defmodule Fishjam.ConfigReader do
  @moduledoc false

  require Logger

  def read_port_range(env) do
    if value = get_env(env) do
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
    if value = get_env(env) do
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

  def read_and_resolve_hostname(env) do
    if value = get_env(env) do
      # resolve_hostname will raise if address is invalid/unresolvable
      {:ok, resolved_ip} = value |> resolve_hostname() |> to_charlist() |> :inet.parse_address()

      resolved_ip
    end
  end

  def read_port(env) do
    if value = get_env(env) do
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
    if value = get_env(env) do
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

  def read_ssl_config() do
    ssl_key_path = get_env("FJ_SSL_KEY_PATH")
    ssl_cert_path = get_env("FJ_SSL_CERT_PATH")

    case {ssl_key_path, ssl_cert_path} do
      {nil, nil} ->
        nil

      {nil, ssl_cert_path} when ssl_cert_path != nil ->
        raise "FJ_SSL_CERT_PATH has been set but FJ_SSL_KEY_PATH remains unset"

      {ssl_key_path, nil} when ssl_key_path != nil ->
        raise "FJ_SSL_KEY_PATH has been set but FJ_SSL_CERT_PATH remains unset"

      other ->
        other
    end
  end

  def read_webrtc_config() do
    webrtc_used? = read_boolean("FJ_WEBRTC_USED")

    if webrtc_used? != false do
      [
        webrtc_used?: true,
        turn_ip: read_ip("FJ_WEBRTC_TURN_IP") || {127, 0, 0, 1},
        turn_listen_ip: read_and_resolve_hostname("FJ_WEBRTC_TURN_LISTEN_IP") || {127, 0, 0, 1},
        turn_port_range: read_port_range("FJ_WEBRTC_TURN_PORT_RANGE") || {50_000, 59_999},
        turn_tcp_port: read_port("FJ_WEBRTC_TURN_TCP_PORT")
      ]
    else
      [
        webrtc_used?: false,
        turn_ip: nil,
        turn_listen_ip: nil,
        turn_port_range: nil,
        turn_tcp_port: nil
      ]
    end
  end

  def read_components_used() do
    components_used = get_env("FJ_COMPONENTS_USED") || ""

    components_used
    |> String.split(" ", trim: true)
    |> Enum.map(fn type ->
      case Fishjam.Component.parse_type(type) do
        {:ok, component} ->
          component

        {:error, :invalid_type} ->
          raise(
            "Invalid value in FJ_COMPONENTS_USED. Expected a lowercase component name, got: #{type}"
          )
      end
    end)
  end

  def read_sip_config(sip_used?) do
    sip_ip = get_env("FJ_SIP_IP") || ""

    cond do
      sip_used? != true ->
        [
          sip_external_ip: nil
        ]

      ip_address?(sip_ip) ->
        [
          sip_external_ip: sip_ip
        ]

      true ->
        raise """
        SIP components are allowed, but incorrect IP address was provided as `FJ_SIP_IP`
        """
    end
  end

  def read_s3_config() do
    credentials = [
      bucket: get_env("FJ_S3_BUCKET"),
      region: get_env("FJ_S3_REGION"),
      access_key_id: get_env("FJ_S3_ACCESS_KEY_ID"),
      secret_access_key: get_env("FJ_S3_SECRET_ACCESS_KEY")
    ]

    path_prefix = get_env("FJ_S3_PATH_PREFIX")

    credentials =
      cond do
        Enum.all?(credentials, fn {_key, val} -> not is_nil(val) end) ->
          credentials

        Enum.all?(credentials, fn {_key, val} -> is_nil(val) end) ->
          nil

        true ->
          missing_envs =
            credentials
            |> Enum.filter(fn {_key, val} -> val == nil end)
            |> Enum.map(fn {key, _val} ->
              "FJ_" <> (key |> Atom.to_string() |> String.upcase())
            end)

          raise """
          Either all S3 credentials have to be set: `FJ_S3_BUCKET`, `FJ_S3_REGION`, `FJ_S3_ACCESS_KEY_ID`, `FJ_S3_SECRET_ACCESS_KEY`, or none must be set.
          Currently, the following required credentials are missing: #{inspect(missing_envs)}.
          """
      end

    [
      path_prefix: path_prefix,
      credentials: credentials
    ]
  end

  def read_dist_config() do
    dist_enabled? = read_boolean("FJ_DIST_ENABLED")
    dist_strategy = get_env("FJ_DIST_STRATEGY_NAME")
    mode_value = get_env("FJ_DIST_MODE", "sname")
    cookie_value = get_env("FJ_DIST_COOKIE", "fishjam_cookie")

    {:ok, hostname} = :inet.gethostname()
    node_name_value = get_env("FJ_DIST_NODE_NAME", "fishjam@#{hostname}")

    cookie = parse_cookie(cookie_value)
    mode = parse_mode(mode_value)

    cond do
      is_nil(dist_enabled?) or not dist_enabled? ->
        [
          enabled: false,
          mode: nil,
          strategy: nil,
          node_name: nil,
          cookie: nil,
          strategy_config: nil
        ]

      dist_strategy == "NODES_LIST" or is_nil(dist_strategy) ->
        do_read_nodes_list_config(node_name_value, cookie, mode)

      dist_strategy == "DNS" ->
        do_read_dns_config(node_name_value, cookie, mode)

      true ->
        raise """
        FJ_DIST_ENABLED has been set but unknown FJ_DIST_STRATEGY was provided.
        Availabile strategies are EPMD or DNS, provided strategy name was: "#{dist_strategy}"
        """
    end
  end

  def read_git_commit() do
    get_env("FJ_GIT_COMMIT", "dev")
  end

  def read_string(string, default \\ nil) do
    get_env(string, default)
  end

  def read_logger_level() do
    log_level = System.get_env("FJ_LOG_LEVEL", "info")

    log_levels_string = ["info", "debug", "warning", "error"]

    if log_level in log_levels_string do
      String.to_atom(log_level)
    else
      Logger.warning("""
      Provided unknown level of logs: #{log_level}. Valid values are #{Enum.join(log_levels_string, ", ")}.
      Set value to default - info.
      """)

      :info
    end
  end

  defp do_read_nodes_list_config(node_name_value, cookie, mode) do
    nodes_value = get_env("FJ_DIST_NODES", "")

    node_name = parse_node_name(node_name_value)
    nodes = parse_nodes(nodes_value)

    if nodes == [] do
      Logger.warning("""
      NODES_LIST strategy requires FJ_DIST_NODES to be set
      by at least one Fishjam instace. This instance has FJ_DIST_NODES unset.
      """)
    end

    [
      enabled: true,
      mode: mode,
      strategy: Cluster.Strategy.Epmd,
      node_name: node_name,
      cookie: cookie,
      strategy_config: [hosts: nodes]
    ]
  end

  defp do_read_dns_config(_node_name_value, _cookie, :shortnames) do
    raise "DNS strategy requires `FJ_DIST_MODE` to be `name`"
  end

  defp do_read_dns_config(node_name_value, cookie, mode) do
    # Verify the node name is formatted correctly
    _node_name = parse_node_name(node_name_value)

    query_value = get_env("FJ_DIST_QUERY")

    unless query_value do
      raise "FJ_DIST_QUERY is required by DNS strategy"
    end

    [node_basename, hostname | []] = String.split(node_name_value, "@")
    resolved_hostname = resolve_hostname(hostname)
    node_name = String.to_atom("#{node_basename}@#{resolved_hostname}")

    polling_interval = parse_polling_interval()

    [
      enabled: true,
      mode: mode,
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
        raise "FJ_DIST_NODE_NAME has to be in form of <nodename>@<hostname>. Got: #{node_name}"
    end
  end

  defp parse_cookie(cookie_value), do: String.to_atom(cookie_value)

  defp parse_nodes(nodes_value) do
    nodes_value
    |> String.split(" ", trim: true)
    |> Enum.map(&String.to_atom(&1))
  end

  defp parse_polling_interval() do
    env_value = get_env("FJ_DIST_POLLING_INTERVAL", "5000")

    case Integer.parse(env_value) do
      {polling_interval, ""} when polling_interval > 0 ->
        polling_interval

      _other ->
        raise "`FJ_DIST_POLLING_INTERVAL` must be a positivie integer. Got: #{env_value}"
    end
  end

  defp parse_mode("name"), do: :longnames
  defp parse_mode("sname"), do: :shortnames
  defp parse_mode(other), do: raise("Invalid FJ_DIST_MODE. Expected sname or name, got: #{other}")

  defp ip_address?(hostname) do
    case :inet.parse_address(String.to_charlist(hostname)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp resolve_hostname(hostname) do
    case :inet.gethostbyname(String.to_charlist(hostname)) do
      {:ok, {:hostent, _, _, _, _, h_addr_list}} ->
        # Assert there is at least one ip address.
        # In other case, this is fatal error
        [h | _] = h_addr_list
        resolved_hostname = "#{:inet.ntoa(h)}"

        if resolved_hostname != hostname,
          do: Logger.info("Resolved #{hostname} as #{resolved_hostname}")

        resolved_hostname

      {:error, reason} ->
        raise """
        Couldn't resolve #{hostname}, reason: #{reason}.
        """
    end
  end

  defp get_env("FJ_" <> rest = name, default \\ nil) do
    fj_name = name
    jf_name = "JF_" <> rest

    fj_var = System.get_env(fj_name)
    jf_var = System.get_env(jf_name)

    if jf_var != nil do
      Logger.warning("""
      It looks like you have still an env variable prefixed with JF_ set.
      Support for those variables will be removed in version 0.8.0.
      Variable: #{jf_name}
      """)
    end

    fj_var || jf_var || default
  end
end
