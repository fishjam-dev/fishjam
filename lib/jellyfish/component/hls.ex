defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config
  @behaviour Jellyfish.Component

  alias Jellyfish.Component.HLS.{LLStorage, RequestHandler}
  alias Jellyfish.Room

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{CompositorConfig, HLSConfig, MixerConfig}
  alias Membrane.Time

  @segment_duration Time.seconds(4)
  @partial_segment_duration Time.milliseconds(400)

  @type metadata :: %{playable: boolean()}

  @impl true
  def config(options) do
    storage = fn directory -> %LLStorage{directory: directory, room_id: options.room_id} end
    RequestHandler.start(options.room_id)

    {:ok,
     %HLS{
       rtc_engine: options.engine_pid,
       owner: self(),
       output_directory: output_dir(options.room_id),
       mixer_config: %MixerConfig{
         video: %CompositorConfig{
           stream_format: %Membrane.RawVideo{
             width: 1920,
             height: 1080,
             pixel_format: :I420,
             framerate: {24, 1},
             aligned: true
           }
         }
       },
       hls_config: %HLSConfig{
         hls_mode: :muxed_av,
         mode: :live,
         target_window_duration: :infinity,
         segment_duration: @segment_duration,
         partial_segment_duration: @partial_segment_duration,
         storage: storage
       }
     }}
  end

  @impl true
  def metadata(), do: %{playable: false}

  @spec output_dir(Room.id()) :: String.t()
  def output_dir(room_id) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    Path.join([base_path, "hls_output", "#{room_id}"])
  end
end
