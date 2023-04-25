defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.HLSConfig

  @impl true
  def config(options) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    output_dir = Path.join([base_path, "hls_output", "#{options.room_id}"])

    {:ok,
     %HLS{
       rtc_engine: options.engine_pid,
       owner: self(),
       output_directory: output_dir,
       mixer_config: nil,
       hls_config: %HLSConfig{}
     }}
  end
end
