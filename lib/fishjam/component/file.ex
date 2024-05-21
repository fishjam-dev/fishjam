defmodule Fishjam.Component.File do
  @moduledoc """
  Module representing the File component.
  """

  @behaviour Fishjam.Endpoint.Config
  use Fishjam.Component

  alias ExSDP.Attribute.FMTP
  alias Membrane.RTC.Engine.Endpoint.File, as: FileEndpoint

  alias Fishjam.Utils.PathValidation
  alias FishjamWeb.ApiSpec.Component.File.Options

  @type properties :: %{
          file_path: Path.t(),
          framerate: non_neg_integer() | nil
        }

  @files_location "file_component_sources"

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()),
         :ok <- validate_file_path(valid_opts.filePath),
         path = expand_file_path(valid_opts.filePath),
         {:ok, framerate} <- validate_framerate(valid_opts.framerate),
         {:ok, track_config} <-
           get_track_config(path, framerate) do
      endpoint_spec = %FileEndpoint{
        rtc_engine: engine,
        file_path: path,
        track_config: track_config,
        payload_type: track_config.fmtp.pt
      }

      properties = valid_opts |> Map.from_struct()

      new_framerate =
        if track_config.type == :video do
          {framerate, 1} = track_config.opts[:framerate]
          framerate
        else
          nil
        end

      {:ok, %{endpoint: endpoint_spec, properties: %{properties | framerate: new_framerate}}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name}]} ->
        {:error, {:missing_parameter, name}}

      {:error, [%OpenApiSpex.Cast.Error{reason: :invalid_type, value: value, path: [:framerate]}]} ->
        {:error, {:invalid_framerate, value}}

      {:error, _reason} = error ->
        error
    end
  end

  defp validate_file_path(file_path) do
    base_path =
      Application.fetch_env!(:fishjam, :media_files_path)
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
    media_files_path = Application.fetch_env!(:fishjam, :media_files_path)
    [media_files_path, @files_location, file_path] |> Path.join() |> Path.expand()
  end

  defp get_track_config(file_path, framerate) do
    file_path |> Path.extname() |> do_get_track_config(framerate)
  end

  defp do_get_track_config(".h264", framerate) do
    {:ok,
     %FileEndpoint.TrackConfig{
       type: :video,
       encoding: :H264,
       clock_rate: 90_000,
       fmtp: %FMTP{pt: 96},
       opts: [framerate: {framerate || 30, 1}]
     }}
  end

  defp do_get_track_config(".ogg", nil) do
    {:ok,
     %FileEndpoint.TrackConfig{
       type: :audio,
       encoding: :OPUS,
       clock_rate: 48_000,
       fmtp: %FMTP{pt: 108}
     }}
  end

  defp do_get_track_config(".ogg", _not_nil) do
    {:error, :bad_parameter_framerate_for_audio}
  end

  defp do_get_track_config(_extension, _framerate), do: {:error, :unsupported_file_type}

  defp validate_framerate(nil), do: {:ok, nil}
  defp validate_framerate(num) when is_number(num) and num > 0, do: {:ok, num}
  defp validate_framerate(other), do: {:error, {:invalid_framerate, other}}
end
