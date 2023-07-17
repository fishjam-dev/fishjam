defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{CompositorConfig, HLSConfig, MixerConfig}
  alias Membrane.Time

  @segment_duration Time.seconds(4)
  @partial_segment_duration Time.milliseconds(400)

  @impl true
  def config(options) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    output_dir = Path.join([base_path, "hls_output", "#{options.room_id}"])

    {:ok,
     %HLS{
       rtc_engine: options.engine_pid,
       owner: self(),
       output_directory: output_dir,
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
         partial_segment_duration: @partial_segment_duration
       }
     }}
  end
end
