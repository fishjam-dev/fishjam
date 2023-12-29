defmodule Jellyfish.ConfigReaderTest do
  use ExUnit.Case

  # run this test synchronously as we use
  # official env vars in read_dist_config test

  alias Jellyfish.ConfigReader

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
    env_name = "JF_CONF_READER_TEST_IP"

    with_env env_name do
      System.put_env(env_name, "127.0.0.1")
      assert ConfigReader.read_ip(env_name) == {127, 0, 0, 1}
      System.delete_env(env_name)
      assert ConfigReader.read_ip(env_name) == nil
      System.put_env(env_name, "example.com")
      assert_raise RuntimeError, fn -> ConfigReader.read_ip(env_name) end
    end
  end

  test "read_port/1" do
    env_name = "JF_CONF_READER_TEST_PORT"

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
    env_name = "JF_CONF_READER_TEST_BOOL"

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
    env_name = "JF_CHECK_ORIGIN"

    with_env env_name do
      System.put_env(env_name, "false")
      assert ConfigReader.read_check_origin(env_name) == false
      System.put_env(env_name, "true")
      assert ConfigReader.read_check_origin(env_name) == true
      System.put_env(env_name, "jellyfish.ovh jellyfish2.ovh jellyfish3.ovh")

      assert ConfigReader.read_check_origin(env_name) == [
               "jellyfish.ovh",
               "jellyfish2.ovh",
               "jellyfish3.ovh"
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
    env_name = "JF_CONF_READER_TEST_PORT_RANGE"

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
    with_env ["JF_SSL_KEY_PATH", "JF_SSL_CERT_PATH"] do
      assert ConfigReader.read_ssl_config() == nil

      System.put_env("JF_SSL_KEY_PATH", "/some/key/path")
      assert_raise RuntimeError, fn -> ConfigReader.read_ssl_config() end
      System.delete_env("JF_SSL_KEY_PATH")

      System.put_env("JF_SSL_CERT_PATH", "/some/cert/path")
      assert_raise RuntimeError, fn -> ConfigReader.read_ssl_config() end

      System.put_env("JF_SSL_KEY_PATH", "/some/key/path")
      assert ConfigReader.read_ssl_config() == {"/some/key/path", "/some/cert/path"}
    end
  end

  test "read_dist_config/0 NODES_LIST" do
    with_env [
      "JF_DIST_ENABLED",
      "JF_DIST_MODE",
      "JF_DIST_COOKIE",
      "JF_DIST_NODE_NAME",
      "JF_DIST_NODES"
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

      System.put_env("JF_DIST_ENABLED", "true")

      assert ConfigReader.read_dist_config() == [
               enabled: true,
               mode: :shortnames,
               strategy: Cluster.Strategy.Epmd,
               node_name: :"jellyfish@#{hostname}",
               cookie: :jellyfish_cookie,
               strategy_config: [hosts: []]
             ]

      System.put_env("JF_DIST_NODE_NAME", "testnodename@abc@def")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("JF_DIST_NODE_NAME", "testnodename")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.delete_env("JF_DIST_NODE_NAME")
      assert ConfigReader.read_dist_config()
      System.put_env("JF_DIST_MODE", "invalid")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end

      System.put_env("JF_DIST_MODE", "name")
      System.put_env("JF_DIST_COOKIE", "testcookie")
      System.put_env("JF_DIST_NODE_NAME", "testnodename@127.0.0.1")
      System.put_env("JF_DIST_NODES", "testnodename1@127.0.0.1 testnodename2@127.0.0.1")

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
      "JF_DIST_ENABLED",
      "JF_DIST_MODE",
      "JF_DIST_COOKIE",
      "JF_DIST_NODE_NAME",
      "JF_DIST_NODES",
      "JF_DIST_STRATEGY_NAME"
    ] do
      assert ConfigReader.read_dist_config() == [
               enabled: false,
               mode: nil,
               strategy: nil,
               node_name: nil,
               cookie: nil,
               strategy_config: nil
             ]

      System.put_env("JF_DIST_ENABLED", "true")
      System.put_env("JF_DIST_MODE", "name")
      System.put_env("JF_DIST_STRATEGY_NAME", "DNS")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("JF_DIST_QUERY", "my-app.example.com")

      assert [
               enabled: true,
               mode: :longnames,
               strategy: Cluster.Strategy.DNSPoll,
               node_name: _node_name,
               cookie: :jellyfish_cookie,
               strategy_config: [
                 polling_interval: 5_000,
                 query: "my-app.example.com",
                 node_basename: "jellyfish"
               ]
             ] = ConfigReader.read_dist_config()

      System.put_env("JF_DIST_COOKIE", "testcookie")
      System.put_env("JF_DIST_NODE_NAME", "testnodename@127.0.0.1")

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
        "JF_DIST_POLLING_INTERVAL",
        "10000"
      )

      # check if hostname is resolved correctly
      System.put_env("JF_DIST_NODE_NAME", "testnodename@localhost")

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

      System.put_env("JF_DIST_POLLING_INTERVAL", "abcd")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
      System.put_env("JF_DIST_POLLING_INTERVAL", "-25")
      assert_raise RuntimeError, fn -> ConfigReader.read_dist_config() end
    end
  end
end
