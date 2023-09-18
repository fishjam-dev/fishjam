defmodule Jellyfish.ConfigReaderTest do
  use ExUnit.Case, async: true

  alias Jellyfish.ConfigReader

  defmacrop with_env(env, do: body) do
    quote do
      old = System.get_env(unquote(env))
      unquote(body)

      if old do
        System.put_env(unquote(env), old)
      else
        System.delete_env(unquote(env))
      end
    end
  end

  test "read_ip/1" do
    env_name = "JF_CONF_READER_TEST_IP"

    with_env env_name do
      System.put_env(env_name, "127.0.0.1")
      assert ConfigReader.read_ip(env_name) == {127, 0, 0, 1}
      :os.unsetenv(to_charlist(env_name))
      assert ConfigReader.read_ip(env_name) == nil
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
      for {env_value, expected_value} <- [
            {"f", false},
            {"0", false},
            {"false", false},
            {"1", true},
            {"true", true}
          ] do
        System.put_env(env_name, env_value)
        assert ConfigReader.read_boolean(env_name) == expected_value
      end
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

  test "read_nodes/1" do
    env_name = "JF_CONF_READER_TEST_NODES"

    with_env env_name do
      System.put_env(env_name, "app1@127.0.0.1 app2@127.0.0.2")
      assert ConfigReader.read_nodes(env_name) == [:"app1@127.0.0.1", :"app2@127.0.0.2"]
    end
  end
end
