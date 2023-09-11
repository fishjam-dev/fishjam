defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Jellyfish.Component.HLS.{LLStorage, RequestHandler, Storage}
  alias Jellyfish.Room

  alias JellyfishWeb.ApiSpec

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{CompositorConfig, HLSConfig, MixerConfig}
  alias Membrane.Time

  @segment_duration Time.seconds(6)
  @partial_segment_duration Time.milliseconds(1_100)

  @type metadata :: %{
          playable: boolean(),
          low_latency: boolean()
        }

  @impl true
  def config(options) do
    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Component.HLS.schema()) do
      low_latency? = valid_opts.lowLatency
      hls_config = create_hls_config(options.room_id, low_latency?: low_latency?)

      {:ok,
       %{
         endpoint: %HLS{
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
           hls_config: hls_config
         },
         metadata: %{
           playable: false,
           low_latency: low_latency?
         }
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  @spec output_dir(Room.id()) :: String.t()
  def output_dir(room_id) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    Path.join([base_path, "hls_output", "#{room_id}"])
  end

  defp create_hls_config(room_id, low_latency?: low_latency?) do
    partial_duration = if low_latency?, do: @partial_segment_duration, else: nil
    hls_storage = setup_hls_storage(room_id, low_latency?: low_latency?)

    %HLSConfig{
      hls_mode: :muxed_av,
      mode: :live,
      target_window_duration: :infinity,
      segment_duration: @segment_duration,
      partial_segment_duration: partial_duration,
      storage: hls_storage
    }
  end

  defp setup_hls_storage(room_id, low_latency?: true) do
    RequestHandler.start(room_id)

    fn directory -> %LLStorage{directory: directory, room_id: room_id} end
  end

  defp setup_hls_storage(_room_id, low_latency?: false) do
    fn directory -> %Storage{directory: directory} end
  end
end
