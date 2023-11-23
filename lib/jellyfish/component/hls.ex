defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Jellyfish.Component.HLS.{LLStorage, Recording, Storage}
  alias Jellyfish.Room

  alias JellyfishWeb.ApiSpec.Component.HLS.Options

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{CompositorConfig, HLSConfig, MixerConfig}
  alias Membrane.Time

  @segment_duration Time.seconds(6)
  @partial_segment_duration Time.milliseconds(1_100)
  @type metadata :: %{
          optional(:target_window_duration) => pos_integer(),
          playable: boolean(),
          low_latency: boolean(),
          persistent: boolean()
        }

  @impl true
  def config(options) do
    with {:ok, valid_opts} <- serialize_options(options) do
      hls_config = create_hls_config(options.room_id, valid_opts)

      metadata =
        valid_opts
        |> Map.put(:playable, false)
        |> Enum.into(%{})

      {:ok,
       %{
         endpoint: %HLS{
           rtc_engine: options.engine_pid,
           owner: self(),
           output_directory: output_dir(options.room_id, persistent: metadata.persistent),
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
           hls_config: hls_config,
           subscribe_mode: valid_opts.subscribe_mode
         },
         metadata: metadata
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  @spec output_dir(Room.id(), persistent: boolean()) :: String.t()
  def output_dir(room_id, persistent: true) do
    Recording.directory(room_id)
  end

  def output_dir(room_id, persistent: false) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    Path.join([base_path, "temporary_hls", "#{room_id}"])
  end

  def serialize_options(options) do
    with {:ok, valid_opts} <- OpenApiSpex.Cast.cast(Options.schema(), options) do
      valid_opts =
        valid_opts
        |> Map.from_struct()
        |> Map.new(fn {k, v} -> {underscore(k), serialize(v)} end)
        |> Map.update!(:subscribe_mode, &String.to_atom/1)

      {:ok, valid_opts}
    else
      {:error, _reason} = error -> error
    end
  end

  defp create_hls_config(
         room_id,
         %{
           low_latency: low_latency,
           target_window_duration: target_window_duration,
           persistent: persistent
         }
       ) do
    partial_duration = if low_latency, do: @partial_segment_duration, else: nil
    hls_storage = setup_hls_storage(room_id, low_latency: low_latency)

    %HLSConfig{
      hls_mode: :muxed_av,
      mode: :live,
      target_window_duration: target_window_duration || :infinity,
      segment_duration: @segment_duration,
      partial_segment_duration: partial_duration,
      persist?: persistent,
      storage: hls_storage
    }
  end

  defp setup_hls_storage(room_id, low_latency: true) do
    fn directory -> %LLStorage{directory: directory, room_id: room_id} end
  end

  defp setup_hls_storage(_room_id, low_latency: false) do
    fn directory -> %Storage{directory: directory} end
  end

  defp underscore(k), do: k |> Atom.to_string() |> Macro.underscore() |> String.to_atom()

  defp serialize(v) when is_struct(v),
    do: v |> Map.from_struct() |> Map.new(fn {k, v} -> {underscore(k), v} end)

  defp serialize(v), do: v
end
