defmodule Jellyfish.Utils.PathValidation do
  @moduledoc """
  A helper module for validating file and directory paths.
  This module is mainly used to validate filenames and paths embedded in requests.
  """

  @doc """
  Checks if a given path is contained within a provided directory.
  Remember to use expanded paths.
  ## Params:

  - `path`: The path to the file or directory you want to check.
  - `directory`: The base directory you want to ensure the path is contained within.

  ## Example:

      iex> Jellyfish.Utils.PathValidation.inside_directory?("relative/path/to/file", "relative/path")
      true

      iex> Jellyfish.Utils.PathValidation.inside_directory?("/absolute/path/to/file", "relative/path")
      false

  """
  @spec inside_directory?(Path.t(), Path.t()) :: boolean()
  def inside_directory?(path, directory) do
    relative_path = Path.relative_to(path, directory)
    relative_path != path and relative_path != "."
  end
end
