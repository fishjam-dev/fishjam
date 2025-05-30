defmodule Fishjam.Component.Recording do
  @moduledoc """
  Module representing the Recording component.
  """

  @behaviour Fishjam.Endpoint.Config
  use Fishjam.Component

  alias FishjamWeb.ApiSpec.Component.Recording.Options
  alias Membrane.RTC.Engine.Endpoint.Recording

  @type properties :: %{path_prefix: Path.t()}

  @impl true
  def config(%{engine_pid: engine} = options) do
    sink_config = Application.fetch_env!(:fishjam, :s3_config)

    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()),
         result_opts <- parse_subscribe_mode(serialized_opts),
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
        stores: [file_storage, s3_storage],
        subscribe_mode: result_opts.subscribe_mode
      }

      {:ok,
       %{
         endpoint: endpoint,
         properties: %{subscribe_mode: result_opts.subscribe_mode}
       }}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name} | _rest]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end

  def get_base_path(),
    do: :fishjam |> Application.fetch_env!(:media_files_path) |> Path.join("raw_recordings")

  defp parse_subscribe_mode(opts) do
    Map.update!(opts, :subscribe_mode, &String.to_atom/1)
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
end
