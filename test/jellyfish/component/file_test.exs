defmodule Jellyfish.Component.FileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias ExSDP.Attribute.FMTP

  alias Jellyfish.Component
  alias Membrane.RTC.Engine.Endpoint

  @engine_pid "placeholder"
  @video_file_path "test/fixtures/video.h264"
  @audio_file_path "test/fixtures/audio.opus"
  @missing_file_path "test/fixtures/video.opus"
  @properties %{}
  @jellyfish_opts %{engine_pid: @engine_pid, room_id: "example-room-id"}

  test "video file" do
    options = Map.put(@jellyfish_opts, "filePath", @video_file_path)

    expected = %Endpoint.File{
      rtc_engine: @engine_pid,
      file_path: @video_file_path,
      track_config: %Endpoint.File.TrackConfig{
        type: :video,
        encoding: :H264,
        clock_rate: 90000,
        fmtp: %FMTP{pt: 96},
        opts: [
          framerate: {30, 1}
        ]
      },
      payload_type: 96
    }

    {:ok, %{endpoint: ^expected, properties: @properties}} = Component.File.config(options)
  end

  test "audio file" do
    options = Map.put(@jellyfish_opts, "filePath", @audio_file_path)

    expected = %Endpoint.File{
      rtc_engine: @engine_pid,
      file_path: @audio_file_path,
      track_config: %Endpoint.File.TrackConfig{
        type: :audio,
        encoding: :OPUS,
        clock_rate: 48000,
        fmtp: %FMTP{pt: 108},
        opts: []
      },
      payload_type: 108
    }

    {:ok, %{endpoint: ^expected, properties: @properties}} = Component.File.config(options)
  end

  test "path for non-existent file" do
    options = Map.put(@jellyfish_opts, "filePath", @missing_file_path)

    {:error, :file_does_not_exist} = Component.File.config(options)
  end

  test "missing filePath" do
    reason = [
      %OpenApiSpex.Cast.Error{
        reason: :missing_field,
        value: %{},
        format: nil,
        type: nil,
        name: :filePath,
        path: [:filePath],
        length: 0,
        meta: %{}
      }
    ]

    {:error, ^reason} = Component.File.config(@jellyfish_opts)
  end
end
