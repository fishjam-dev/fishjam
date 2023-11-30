defmodule Jellyfish.Component.File do
  @moduledoc """
  Module representing the File component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias ExSDP.Attribute.FMTP

  alias Membrane.RTC.Engine.Endpoint.File, as: FileEndpoint
  alias JellyfishWeb.ApiSpec.Component.File.Options

  @type properties :: %{}

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()),
         {:ok, file_path} <- ensure_exists(valid_opts.filePath) do
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

  defp ensure_exists(file_path) do
    if File.exists?(file_path) do
      {:ok, file_path}
    else
      {:error, :file_does_not_exist}
    end
  end

  defp get_track_config(file_path) do
    String.split(file_path, ".") |> List.last() |> do_get_track_config()
  end

  defp do_get_track_config("h264") do
    %FileEndpoint.TrackConfig{
      type: :video,
      encoding: :H264,
      clock_rate: 90000,
      fmtp: %FMTP{pt: 96},
      opts: [framerate: {30, 1}]
    }
  end

  defp do_get_track_config(_audio) do
    %FileEndpoint.TrackConfig{
      type: :audio,
      encoding: :OPUS,
      clock_rate: 48_000,
      fmtp: %FMTP{pt: 108}
    }
  end
end
