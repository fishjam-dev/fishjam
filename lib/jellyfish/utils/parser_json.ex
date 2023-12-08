defmodule Jellyfish.Utils.ParserJSON do
  @moduledoc """
  A utility module for converting controller responses into JSON format.
  """

  @doc """
  Convert all keys in map from snake_case to camelCase
  """
  @spec camel_case_keys(%{atom() => term()}) :: %{String.t() => term()}
  def camel_case_keys(map) do
    Map.new(map, fn {k, v} -> {snake_case_to_camel_case(k), v} end)
  end

  # Macro.underscore/camelize:
  # Do not use it as a general mechanism for underscoring strings as it does
  # not support Unicode or characters that are not valid in Elixir identifiers.
  defp snake_case_to_camel_case(atom) do
    [first | rest] = "#{atom}" |> String.split("_")
    rest = rest |> Enum.map(&String.capitalize/1)
    Enum.join([first | rest])
  end
end
