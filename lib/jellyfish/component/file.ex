defmodule Jellyfish.Component.File do
  @moduledoc """
  Module representing the File component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias ExSDP.Attribute.FMTP
  alias JellyfishWeb.ApiSpec.Component.File.Options
  alias Membrane.RTC.Engine.Endpoint.File, as: FileEndpoint

  @type properties :: %{}
  @allowed_extensions [".opus", ".h264"]

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()),
         {:ok, file_path} <- validate_file_path(valid_opts.filePath) do
      track_config = get_track_config(file_path)

      endpoint_spec =
        %FileEndpoint{
          rtc_engine: engine,
          file_path: file_path,
          track_config: track_config,
          payload_type: track_config.fmtp.pt
        }

      {:ok, %{endpoint: endpoint_spec, properties: %{}}}
    else
      {:error, _reason} = error -> error
    end
  end

  defp validate_file_path(file_path) do
    cond do
      not File.exists?(file_path) -> {:error, :file_does_not_exist}
      Path.extname(file_path) not in @allowed_extensions -> {:error, :invalid_extension}
      true -> {:ok, file_path}
    end
  end

  defp get_track_config(file_path) do
    file_path |> Path.extname() |> do_get_track_config()
  end

  defp do_get_track_config(".h264") do
    %FileEndpoint.TrackConfig{
      type: :video,
      encoding: :H264,
      clock_rate: 90_000,
      fmtp: %FMTP{pt: 96},
      opts: [framerate: {30, 1}]
    }
  end

  defp do_get_track_config(".opus") do
    %FileEndpoint.TrackConfig{
      type: :audio,
      encoding: :OPUS,
      clock_rate: 48_000,
      fmtp: %FMTP{pt: 108}
    }
  end
end
