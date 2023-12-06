defmodule Jellyfish.Utils do
  @moduledoc false

  @doc "Convert all keys in map from snake_case to camelCase"
  @spec camel_case_keys(%{atom() => term()}) :: %{String.t() => term()}
  def camel_case_keys(map) do
    Map.new(map, fn {k, v} -> {snake_case_to_camel_case(k), v} end)
  end

  @doc """
  Checks if a given path is contained within a provided directory.
  Remember to use expanded paths.
  ## Params:

  - `path`: The path to the file or directory you want to check.
  - `directory`: The base directory you want to ensure the path is contained within.

  ## Example:

      iex> is_inside_directory?("relative/path/to/file", "relative/path")
      true

      iex> is_inside_directory?("/absolute/path/to/file", "relative/path")
      false

  """
  @spec inside_directory?(Path.t(), Path.t()) :: boolean()
  def inside_directory?(path, directory) do
    relative_path = Path.relative_to(path, directory)
    relative_path != path and relative_path != "."
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
