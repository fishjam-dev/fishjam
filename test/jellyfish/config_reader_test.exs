defmodule Fishjam.ConfigReaderTest do
  use ExUnit.Case

  # run this test synchronously as we use
  # official env vars in read_dist_config test

  alias Fishjam.ConfigReader

  defmacrop with_env(env, do: body) do
    # get current env(s) value(s),
    # execute test code,
    # put back original env(s) value(s)
    #
    # if env was not set, we have
    # to call System.delete_env as
    # System.put_env does not accept `nil`
    quote do
      envs = List.wrap(unquote(env))
      old_envs = Enum.map(envs, fn env_name -> {env_name, System.get_env(env_name)} end)

      unquote(body)

      Enum.each(old_envs, fn {env_name, env_value} ->
        if env_value do
          System.put_env(env_name, env_value)
        else
          System.delete_env(env_name)
        end
      end)
    end
  end

  test "read_ip/1" do
    env_name = "FJ_CONF_READER_TEST_IP"

    with_env env_name do
      System.put_env(env_name, "127.0.0.1")
      assert ConfigReader.read_ip(env_name) == {127, 0, 0, 1}
      System.delete_env(env_name)
      assert ConfigReader.read_ip(env_name) == nil
      System.put_env(env_name, "example.com")
      assert_raise RuntimeError, fn -> ConfigReader.read_ip(env_name) end
    end
  end

  test "read_and_resolve_hostname/1" do
    env_name = "FJ_CONF_READER_TEST_HOSTNAME"

    with_env env_name do
      System.put_env(env_name, "127.0.0.1")
      assert ConfigReader.read_and_resolve_hostname(env_name) == {127, 0, 0, 1}

      # On most systems, both of these hostnames will resolve to {127, 0, 0, 1}
      # However, since we can't expect this to always be true,
      # let's settle for asserting that these calls return and not raise an error
      System.put_env(env_name, "localhost")
      assert ConfigReader.read_and_resolve_hostname(env_name)
      {:ok, hostname} = :inet.gethostname()
      System.put_env(env_name, "#{hostname}")
      assert ConfigReader.read_and_resolve_hostname(env_name)

      System.delete_env(env_name)
      assert ConfigReader.read_and_resolve_hostname(env_name) == nil
      System.put_env(env_name, "unresolvable-hostname")
      assert_raise RuntimeError, fn -> ConfigReader.read_and_resolve_hostname(env_name) end
    end
  end

  test "read_port/1" do
    env_name = "FJ_CONF_READER_TEST_PORT"

    with_env env_name do
      System.put_env(env_name, "20000")
      assert ConfigReader.read_port(env_name) == 20_000
      System.put_env(env_name, "65536")
      assert_raise RuntimeError, fn -> ConfigReader.read_port(env_name) end
      System.put_env(env_name, "-1")
      assert_raise RuntimeError, fn -> ConfigReader.read_port(env_name) end
      :os.unsetenv(to_charlist(env_name))
      assert ConfigReader.read_port(env_name) == nil
    end
  end

  test "read_boolean/1" do
    env_name = "FJ_CONF_READER_TEST_BOOL"

    with_env env_name do
      System.put_env(env_name, "false")
      assert ConfigReader.read_boolean(env_name) == false
      System.put_env(env_name, "true")
      assert ConfigReader.read_boolean(env_name) == true
      System.put_env(env_name, "other")
      assert_raise RuntimeError, fn -> ConfigReader.read_boolean(env_name) end
    end
  end

  test "read_check_origin/1" do
    env_name = "FJ_CHECK_ORIGIN"

    with_env env_name do
      System.put_env(env_name, "false")
      assert ConfigReader.read_check_origin(env_name) == false
      System.put_env(env_name, "true")
      assert ConfigReader.read_check_origin(env_name) == true
      System.put_env(env_name, "fishjam.ovh fishjam2.ovh fishjam3.ovh")

      assert ConfigReader.read_check_origin(env_name) == [
               "fishjam.ovh",
               "fishjam2.ovh",
               "fishjam3.ovh"
             ]

      # Case from phoenix documentation
      System.put_env(env_name, "//another.com:888 //*.other.com")
      assert ConfigReader.read_check_origin(env_name) == ["//another.com:888", "//*.other.com"]

      System.put_env(env_name, "localhost")
      assert ConfigReader.read_check_origin(env_name) == ["localhost"]

      System.put_env(env_name, ":conn")
      assert ConfigReader.read_check_origin(env_name) == :conn
    end
  end

  test "read_port_range/1" do
    env_name = "FJ_CONF_READER_TEST_PORT_RANGE"

    with_env env_name do
      System.put_env(env_name, "50000-60000")
      assert ConfigReader.read_port_range(env_name) == {50_000, 60_000}
      System.put_env(env_name, "50000-65536")
      assert_raise RuntimeError, fn -> ConfigReader.read_port_range(env_name) end
      System.put_env(env_name, "-1-65536")
      assert_raise RuntimeError, fn -> ConfigReader.read_port_range(env_name) end
    end
  end

  test "read_ssl_config/0" do
    with_env ["FJ_SSL_KEY_PATH", "FJ_SSL_CERT_PATH"] do
      assert ConfigReader.read_ssl_config() == nil

      System.put_env("FJ_SSL_KEY_PATH", "/some/key/path")
      assert_raise RuntimeError, fn -> ConfigReader.read_ssl_config() end
      System.delete_env("FJ_SSL_KEY_PATH")

      System.put_env("FJ_SSL_CERT_PATH", "/some/cert/path")
      assert_raise RuntimeError, fn -> ConfigReader.read_ssl_config() end

      System.put_env("FJ_SSL_KEY_PATH", "/some/key/path")
      assert ConfigReader.read_ssl_config() == {"/some/key/path", "/some/cert/path"}
    end
  end

  test "read_components_used/0" do
    with_env ["FJ_COMPONENTS_USED"] do
      assert ConfigReader.read_components_used() == []

      System.put_env("FJ_COMPONENTS_USED", "hls")
      assert ConfigReader.read_components_used() == [Fishjam.Component.HLS]

      System.put_env("FJ_COMPONENTS_USED", "recording rtsp    sip ")

      assert ConfigReader.read_components_used() |> Enum.sort() ==
               [Fishjam.Component.Recording, Fishjam.Component.RTSP, Fishjam.Component.SIP]
               |> Enum.sort()

      System.put_env("FJ_COMPONENTS_USED", "file rtsp    invalid_component")
      assert_raise RuntimeError, fn -> ConfigReader.read_components_used() end
    end
  end

  test "read_sip_config/1" do
    with_env ["FJ_SIP_IP"] do
      assert ConfigReader.read_sip_config(false) == [sip_external_ip: nil]

      assert_raise RuntimeError, fn -> ConfigReader.read_sip_config(true) end

      System.put_env("FJ_SIP_IP", "abcdefg")
      assert_raise RuntimeError, fn -> ConfigReader.read_sip_config(true) end

      System.put_env("FJ_SIP_IP", "127.0.0.1")
      assert ConfigReader.read_sip_config(true) == [sip_external_ip: "127.0.0.1"]
    end
  end

  test "read_s3_config/0" do
    with_env [
      "FJ_S3_BUCKET",
      "FJ_S3_ACCESS_KEY_ID",
      "FJ_S3_SECRET_ACCESS_KEY",
      "FJ_S3_REGION",
      "FJ_S3_PATH_PREFIX"
    ] do
      assert ConfigReader.read_s3_config() == [path_prefix: nil, credentials: nil]

      System.put_env("FJ_S3_PATH_PREFIX", "path_prefix")
      assert ConfigReader.read_s3_config() == [path_prefix: "path_prefix", credentials: nil]

      System.put_env("FJ_S3_BUCKET", "bucket")
      assert_raise RuntimeError, fn -> ConfigReader.read_s3_config() end

      System.put_env("FJ_S3_ACCESS_KEY_ID", "id")
      System.put_env("FJ_S3_SECRET_ACCESS_KEY", "key")
      System.put_env("FJ_S3_REGION", "region")

      assert ConfigReader.read_s3_config() == [
               path_prefix: "path_prefix",
               credentials: [
                 bucket: "bucket",
                 region: "region",
                 access_key_id: "id",
                 secret_access_key: "key"
               ]
             ]
    end
  end

  test "read_dist_config/0 NODES_LIST" do
    with_env [
      "FJ_DIST_ENABLED",
      "FJ_DIST_MODE",
      "FJ_DIST_COOKIE",
      "FJ_DIST_NODE_NAME",
      "FJ_DIST_NODES",
      "FJ_DIST_POLLING_INTERVAL"
    ] do
      {:ok, hostname} = :inet.gethostname()

      assert ConfigReader.read_dist_config() == [
               enabled: false,
               mode: nil,
               strategy: nil,
               node_name: nil,
               cookie: nil,
               strategy_config: nil
             ]

      System.put_env("FJ_DIST_ENABLED", "true")

      assert ConfigReader.read_dist_config() == [
               enabled: true,
               mode: :shortnames,
               strategy: Cluster.Strategy.Epmd,
               node_name: :"fishjam@#{hostname}",
               cookie: :fishjam_cookie,
               strategy_config: [hosts: []]
             ]

      System.put_env("FJ_DIST_NODE_NAME", "testnodename@abc@def")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("FJ_DIST_NODE_NAME", "testnodename")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.delete_env("FJ_DIST_NODE_NAME")
      assert ConfigReader.read_dist_config()
      System.put_env("FJ_DIST_MODE", "invalid")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end

      System.put_env("FJ_DIST_MODE", "name")
      System.put_env("FJ_DIST_COOKIE", "testcookie")
      System.put_env("FJ_DIST_NODE_NAME", "testnodename@127.0.0.1")
      System.put_env("FJ_DIST_NODES", "testnodename1@127.0.0.1 testnodename2@127.0.0.1")

      assert ConfigReader.read_dist_config() == [
               enabled: true,
               mode: :longnames,
               strategy: Cluster.Strategy.Epmd,
               node_name: :"testnodename@127.0.0.1",
               cookie: :testcookie,
               strategy_config: [hosts: [:"testnodename1@127.0.0.1", :"testnodename2@127.0.0.1"]]
             ]
    end
  end

  test "read_dist_config/0 DNS" do
    with_env [
      "FJ_DIST_ENABLED",
      "FJ_DIST_MODE",
      "FJ_DIST_COOKIE",
      "FJ_DIST_NODE_NAME",
      "FJ_DIST_NODES",
      "FJ_DIST_STRATEGY_NAME",
      "FJ_DIST_POLLING_INTERVAL"
    ] do
      assert ConfigReader.read_dist_config() == [
               enabled: false,
               mode: nil,
               strategy: nil,
               node_name: nil,
               cookie: nil,
               strategy_config: nil
             ]

      System.put_env("FJ_DIST_ENABLED", "true")
      System.put_env("FJ_DIST_MODE", "name")
      System.put_env("FJ_DIST_STRATEGY_NAME", "DNS")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("FJ_DIST_QUERY", "my-app.example.com")

      assert [
               enabled: true,
               mode: :longnames,
               strategy: Cluster.Strategy.DNSPoll,
               node_name: _node_name,
               cookie: :fishjam_cookie,
               strategy_config: [
                 polling_interval: 5_000,
                 query: "my-app.example.com",
                 node_basename: "fishjam"
               ]
             ] = ConfigReader.read_dist_config()

      System.put_env("FJ_DIST_COOKIE", "testcookie")
      System.put_env("FJ_DIST_NODE_NAME", "testnodename@127.0.0.1")

      assert ConfigReader.read_dist_config() == [
               enabled: true,
               mode: :longnames,
               strategy: Cluster.Strategy.DNSPoll,
               node_name: :"testnodename@127.0.0.1",
               cookie: :testcookie,
               strategy_config: [
                 polling_interval: 5_000,
                 query: "my-app.example.com",
                 node_basename: "testnodename"
               ]
             ]

      System.put_env(
        "FJ_DIST_POLLING_INTERVAL",
        "10000"
      )

      # check if hostname is resolved correctly
      System.put_env("FJ_DIST_NODE_NAME", "testnodename@localhost")

      assert ConfigReader.read_dist_config() == [
               enabled: true,
               mode: :longnames,
               strategy: Cluster.Strategy.DNSPoll,
               node_name: :"testnodename@127.0.0.1",
               cookie: :testcookie,
               strategy_config: [
                 polling_interval: 10_000,
                 query: "my-app.example.com",
                 node_basename: "testnodename"
               ]
             ]

      System.put_env("FJ_DIST_POLLING_INTERVAL", "abcd")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("FJ_DIST_POLLING_INTERVAL", "-25")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
    end
  end

  test "read_logger_level/0" do
    with_env ["FJ_LOG_LEVEL"] do
      env_value_to_log_level = %{
        "info" => :info,
        "debug" => :debug,
        "warning" => :warning,
        "error" => :error,
        "other_env_value" => :info
      }

      for {env_value, log_level} <- env_value_to_log_level do
        System.put_env("FJ_LOG_LEVEL", env_value)
        assert ConfigReader.read_logger_level() == log_level
      end
    end
  end
end
