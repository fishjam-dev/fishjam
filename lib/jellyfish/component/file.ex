defmodule Jellyfish.Component.File do
  @moduledoc """
  Module representing the File component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias ExSDP.Attribute.FMTP
  alias Membrane.RTC.Engine.Endpoint.File, as: FileEndpoint

  alias Jellyfish.Utils.PathValidation
  alias JellyfishWeb.ApiSpec.Component.File.Options

  @type properties :: %{}

  @files_location "file_component_sources"

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()),
         :ok <- validate_file_path(valid_opts.filePath),
         path = expand_file_path(valid_opts.filePath),
         {:ok, track_config} <- get_track_config(path) do
      endpoint_spec =
        %FileEndpoint{
          rtc_engine: engine,
          file_path: path,
          track_config: track_config,
          payload_type: track_config.fmtp.pt
        }

      {:ok, %{endpoint: endpoint_spec, properties: %{}}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name}]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end

  defp validate_file_path(file_path) do
    base_path =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@files_location)
      |> Path.expand()

    file_path = expand_file_path(file_path)

    cond do
      not PathValidation.inside_directory?(file_path, base_path) -> {:error, :invalid_file_path}
      not File.exists?(file_path) -> {:error, :file_does_not_exist}
      true -> :ok
    end
  end

  defp expand_file_path(file_path) do
    media_files_path = Application.fetch_env!(:jellyfish, :media_files_path)
    [media_files_path, @files_location, file_path] |> Path.join() |> Path.expand()
  end

  defp get_track_config(file_path) do
    file_path |> Path.extname() |> do_get_track_config()
  end

  defp do_get_track_config(".h264") do
    {:ok,
     %FileEndpoint.TrackConfig{
       type: :video,
       encoding: :H264,
       clock_rate: 90_000,
       fmtp: %FMTP{pt: 96},
       opts: [framerate: {30, 1}]
     }}
  end

  defp do_get_track_config(".ogg") do
    {:ok,
     %FileEndpoint.TrackConfig{
       type: :audio,
       encoding: :OPUS,
       clock_rate: 48_000,
       fmtp: %FMTP{pt: 108}
     }}
  end

  defp do_get_track_config(_extension), do: {:error, :unsupported_file_type}
end
