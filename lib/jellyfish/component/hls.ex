defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{HLSConfig, MixerConfig}

  @impl true
  def config(options) do
    %HLS{
      rtc_engine: options.engine_pid,
      owner: self(),
      output_directory: "output/#{options.room_id}",
      mixer_config: %MixerConfig{},
      hls_config: %HLSConfig{}
    }
  end
end
