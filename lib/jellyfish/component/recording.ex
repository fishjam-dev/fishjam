defmodule Jellyfish.Component.Recording do
  @moduledoc """
  Module representing the Recording component.
  """

  @behaviour Jellyfish.Endpoint.Config
  use Jellyfish.Component

  alias JellyfishWeb.ApiSpec.Component.Recording.Options
  alias Membrane.RTC.Engine.Endpoint.Recording

  @type properties :: %{path_prefix: Path.t()}

  @impl true
  def config(%{engine_pid: engine} = options) do
    recording_config = Application.fetch_env!(:jellyfish, :recording_config)
    sink_config = Application.fetch_env!(:jellyfish, :s3_config)

    unless recording_config[:recording_used?],
      do:
        raise("""
        Recording components can only be used if JF_RECORDING_USED environmental variable is set to \"true\"
        """)

    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()),
         {:ok, credentials} <- get_credentials(serialized_opts, sink_config),
         {:ok, path_prefix} <- get_path_prefix(serialized_opts, sink_config) do
      datetime = DateTime.utc_now() |> to_string()
      path_suffix = Path.join(options.room_id, "part_#{datetime}")

      path_prefix = Path.join(path_prefix, path_suffix)
      output_dir = Path.join(get_base_path(), path_suffix)

      File.mkdir_p!(output_dir)

      file_storage = {Recording.Storage.File, %{output_dir: output_dir}}
      s3_storage = {Recording.Storage.S3, %{credentials: credentials, path_prefix: path_prefix}}

      endpoint = %Recording{
        rtc_engine: engine,
        recording_id: options.room_id,
        stores: [file_storage, s3_storage]
      }

      {:ok, %{endpoint: endpoint, properties: %{path_prefix: path_prefix}}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name} | _rest]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end

  defp get_credentials(%{credentials: credentials}, s3_config) do
    case {credentials, s3_config[:credentials]} do
      {nil, nil} -> {:error, :missing_s3_credentials}
      {nil, credentials} -> {:ok, Enum.into(credentials, %{})}
      {credentials, nil} -> {:ok, credentials}
      _else -> {:error, :overridding_credentials}
    end
  end

  defp get_path_prefix(%{path_prefix: path_prefix}, s3_config) do
    case {path_prefix, s3_config[:path_prefix]} do
      {nil, nil} -> {:ok, ""}
      {nil, path_prefix} -> {:ok, path_prefix}
      {path_prefix, nil} -> {:ok, path_prefix}
      _else -> {:error, :overridding_path_prefix}
    end
  end

  defp get_base_path(),
    do: :jellyfish |> Application.fetch_env!(:media_files_path) |> Path.join("raw_recordings")
end
