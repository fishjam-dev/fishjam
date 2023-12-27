defmodule Jellyfish.Component.FileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias ExSDP.Attribute.FMTP

  alias Jellyfish.Component
  alias Membrane.RTC.Engine.Endpoint

  @engine_pid "placeholder"

  @fixtures_location "test/fixtures"
  @video_filename "video.h264"
  @audio_filename "audio.ogg"

  @properties %{}
  @jellyfish_opts %{engine_pid: @engine_pid, room_id: "example-room-id"}
  @files_location "file_component_sources"

  setup_all do
    base_path =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@files_location)
      |> Path.expand()

    File.mkdir_p!(base_path)

    video_src = Path.join(@fixtures_location, @video_filename)
    video_dst = Path.join(base_path, @video_filename)
    File.cp!(video_src, video_dst)

    audio_src = Path.join(@fixtures_location, @audio_filename)
    audio_dst = Path.join(base_path, @audio_filename)
    File.cp!(audio_src, audio_dst)

    on_exit(fn -> :file.del_dir_r(base_path) end)

    %{
      base_path: base_path,
      video_path: Path.expand(video_dst),
      audio_path: Path.expand(audio_dst)
    }
  end

  test "video file", %{video_path: video_path} do
    endpoint = get_video_endpoint(video_path)
    options = Map.put(@jellyfish_opts, "filePath", @video_filename)

    {:ok, %{endpoint: ^endpoint, properties: @properties}} = Component.File.config(options)
  end

  test "audio file", %{audio_path: audio_path} do
    endpoint = get_audio_endpoint(audio_path)
    options = Map.put(@jellyfish_opts, "filePath", @audio_filename)

    {:ok, %{endpoint: ^endpoint, properties: @properties}} = Component.File.config(options)
  end

  defp get_audio_endpoint(audio_path) do
    %Endpoint.File{
      rtc_engine: @engine_pid,
      file_path: audio_path,
      track_config: %Endpoint.File.TrackConfig{
        type: :audio,
        encoding: :OPUS,
        clock_rate: 48_000,
        fmtp: %FMTP{pt: 108},
        opts: []
      },
      payload_type: 108
    }
  end

  defp get_video_endpoint(video_path) do
    %Endpoint.File{
      rtc_engine: @engine_pid,
      file_path: video_path,
      track_config: %Endpoint.File.TrackConfig{
        type: :video,
        encoding: :H264,
        clock_rate: 90_000,
        fmtp: %FMTP{pt: 96},
        opts: [
          framerate: {30, 1}
        ]
      },
      payload_type: 96
    }
  end
end
