defmodule Jellyfish.ConfigParser do
  @moduledoc false

  def parse_ip(var_value, var_name) do
    var_value = var_value |> to_charlist()

    case :inet.parse_address(var_value) do
      {:ok, parsed_ip} ->
        parsed_ip

      _error ->
        with {:ok, parsed_ip} <- :inet.getaddr(var_value, :inet) do
          parsed_ip
        else
          _error ->
            raise("""
            Bad #{var_name} environment variable value. Expected valid ip address, got: #{var_value}
            """)
        end
    end
  end

  def parse_port(nil, _var_name), do: nil

  def parse_port(var_value, var_name) do
    with {port, _sufix} when port in 1..65_535 <- Integer.parse(var_value) do
      port
    else
      _var ->
        raise("""
        Bad #{var_name} environment variable value. Expected valid port number, got: #{var_value}
        """)
    end
  end

  def parse_port_range(var_value, var_name) do
    with [str1, str2] <- String.split(var_value, "-"),
         from when from in 0..65_535 <- String.to_integer(str1),
         to when to in from..65_535 and from <= to <- String.to_integer(str2) do
      {from, to}
    else
      _else ->
        raise("""
        Bad #{var_name}  environment variable value. Expected "from-to", where `from` and `to` \
        are numbers between 0 and 65535 and `from` is not bigger than `to`, got: #{var_value}
        """)
    end
  end

  def parse_nodes(nodes) do
    nodes
    |> String.split(" ")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_atom(&1))
  end
end
