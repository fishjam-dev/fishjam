defmodule Jellyfish.Component.HLS.Storage.S3 do
  @moduledoc false
  alias Jellyfish.Room

  @behaviour Membrane.HTTPAdaptiveStream.Storage

  @enforce_keys [:room_id, :directory, :config]
  defstruct @enforce_keys ++ []

  @type t :: %__MODULE__{room_id: Room.id(), directory: String.t(), config: Config.t()}

  @impl true
  def init(%__MODULE__{room_id: room_id, directory: directory, config: config}) do
    client =
      config
      |> Enum.reject(fn {key, _value} -> key == :bucket end)
      |> then(&ExAws.Config.new(:s3, &1))

    %{room_id: room_id, directory: directory, client: client, bucket: config.bucket}
  end

  @impl true
  def store(
        _parent_id,
        name,
        content,
        _metadata,
        context,
        %{directory: directory} = state
      ) do
    s3_path = Path.join(state.room_id, name)

    result =
      case context do
        %{mode: :binary, type: :segment} ->
          write_to_s3(s3_path, content, state)
          write_to_file(directory, name, content, [:binary])

        %{mode: :binary, type: :partial_segment} ->
          raise "The S3 storage doesn't support ll-hls."

        %{mode: :binary, type: :header} ->
          write_to_s3(s3_path, content, state, "application/vnd.apple.mpegurl")
          write_to_file(directory, name, content, [:binary])

        %{mode: :text, type: :manifest} ->
          write_to_s3(s3_path, content, state)
          write_to_file(directory, name, content)
      end

    {result, state}
  end

  @impl true
  def remove(_parent_id, name, context, %__MODULE__{directory: directory} = state) do
    result =
      case context do
        %{mode: :binary, type: :partial_segment} ->
          raise "The S3 storage doesn't support ll-hls."

        _else ->
          state.room_id
          |> Path.join(name)
          |> remove_from_s3(state)

          directory
          |> Path.join(name)
          |> File.rm()
      end

    {result, state}
  end

  defp write_to_s3(filepath, content, %{bucket: bucket, client: client}, content_type \\ nil) do
    opts = if is_nil(content_type), do: [], else: [content_type: content_type]

    bucket
    |> ExAws.S3.put_object(filepath, content, opts)
    |> ExAws.request(client)
  end

  defp remove_from_s3(filepath, %{bucket: bucket, client: client}) do
    bucket
    |> ExAws.S3.delete_object(filepath)
    |> ExAws.request(client)
  end

  defp write_to_file(directory, filename, content, write_options \\ []) do
    directory
    |> Path.join(filename)
    |> File.write(content, write_options)
  end
end
