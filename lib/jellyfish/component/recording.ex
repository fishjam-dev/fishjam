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
    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()),
         {:ok, credentials} <- get_credentials(serialized_opts) do
      path_prefix = serialized_opts.path_prefix
      output_dir = Path.join(get_base_path(), path_prefix)

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

  defp get_credentials(%{credentials: nil}) do
    case Application.fetch_env!(:jellyfish, :s3_credentials) do
      nil -> {:error, :missing_s3_credentials}
      credentials -> {:ok, Enum.into(credentials, %{})}
    end
  end

  defp get_credentials(%{credentials: credentials}), do: {:ok, credentials}
  defp get_base_path(), do: Application.fetch_env!(:jellyfish, :media_files_path)
end
