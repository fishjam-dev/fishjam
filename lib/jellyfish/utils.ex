defmodule Jellyfish.Utils do
  @moduledoc false

  @doc "Convert all keys in map from snake_case to camelCase"
  @spec camel_case_keys(%{atom() => term()}) :: %{String.t() => term()}
  def camel_case_keys(map) do
    Map.new(map, fn {k, v} -> {snake_case_to_camel_case(k), v} end)
  end

  defp snake_case_to_camel_case(atom) do
    [first | rest] = "#{atom}" |> String.split("_")
    rest = rest |> Enum.map(&String.capitalize/1)
    Enum.join([first | rest])
  end
end
