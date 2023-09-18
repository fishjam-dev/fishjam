defmodule Jellyfish.ConfigReader do
  @moduledoc false

  def read_port_range(env) do
    if value = System.get_env(env) do
      with [str1, str2] <- String.split(value, "-"),
           from when from in 0..65_535 <- String.to_integer(str1),
           to when to in from..65_535 and from <= to <- String.to_integer(str2) do
        {from, to}
      else
        _else ->
          raise("""
          Bad #{env} environment variable value. Expected "from-to", where `from` and `to` \
          are numbers between 0 and 65535 and `from` is not bigger than `to`, got: \
          #{value}
          """)
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
          case :inet.getaddr(value, :inet) do
            {:ok, parsed_ip} ->
              parsed_ip

            _error ->
              raise("""
              Bad #{env} environment variable value. Expected valid ip address, got: #{value}"
              """)
          end
      end
    end
  end

  def read_port(env) do
    if value = System.get_env(env) do
      case Integer.parse(value) do
        {port, _sufix} when port in 1..65_535 ->
          port

        _other ->
          raise("""
          Bad #{env} environment variable value. Expected valid port number, got: #{value}
          """)
      end
    end
  end

  def read_nodes(env) do
    if value = System.get_env(env) do
      value
      |> String.split(" ")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_atom(&1))
    end
  end

  def read_boolean(env) do
    if value = System.get_env(env) do
      String.downcase(value) not in ["false", "f", "0"]
    end
  end
end
