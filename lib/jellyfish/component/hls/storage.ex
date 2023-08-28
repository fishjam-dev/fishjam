defmodule Jellyfish.Component.HLS.Storage do
  @moduledoc false

  @behaviour Membrane.HTTPAdaptiveStream.Storage

  @enforce_keys [:directory]
  defstruct @enforce_keys ++ []

  @type t :: %__MODULE__{directory: Path.t()}

  @impl true
  def init(%__MODULE__{} = state),
    do: state

  @impl true
  def store(
        _parent_id,
        name,
        content,
        _metadata,
        context,
        %__MODULE__{directory: directory} = state
      ) do
    result =
      case context do
        %{mode: :binary, type: :segment} ->
          write_to_file(directory, name, content, [:binary])

        %{mode: :binary, type: :partial_segment} ->
          raise "This storage doesn't support ll-hls. Use `Jellyfish.Component.HLS.LLStorage` instead"

        %{mode: :binary, type: :header} ->
          write_to_file(directory, name, content, [:binary])

        %{mode: :text, type: :manifest} ->
          write_to_file(directory, name, content)
      end

    {result, state}
  end

  @impl true
  def remove(_parent_id, name, _ctx, %__MODULE__{directory: directory} = state) do
    result =
      directory
      |> Path.join(name)
      |> File.rm()

    {result, state}
  end

  defp write_to_file(directory, filename, content, write_options \\ []) do
    directory
    |> Path.join(filename)
    |> File.write(content, write_options)
  end
end
