defmodule Fishjam.Component.HLS do
  @moduledoc """
  Module representing HLS component.
  """

  @behaviour Fishjam.Endpoint.Config
  use Fishjam.Component

  alias Fishjam.Component.HLS.{
    EtsHelper,
    LLStorage,
    Manager,
    Recording,
    RequestHandler,
    Storage
  }

  alias Fishjam.Room

  alias FishjamWeb.ApiSpec.Component.HLS.Options

  alias Membrane.RTC.Engine.Endpoint.HLS
  alias Membrane.RTC.Engine.Endpoint.HLS.{CompositorConfig, HLSConfig, MixerConfig}
  alias Membrane.Time

  @segment_duration Time.seconds(6)
  @partial_segment_duration Time.milliseconds(1_100)
  @type properties :: %{
          optional(:target_window_duration) => pos_integer(),
          playable: boolean(),
          low_latency: boolean(),
          persistent: boolean()
        }

  @impl true
  def config(options) do
    options = Map.delete(options, "s3")

    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()),
         result_opts <- Map.update!(serialized_opts, :subscribe_mode, &String.to_atom/1) do
      hls_config = create_hls_config(options.room_id, result_opts)

      properties =
        result_opts
        |> Map.put(:playable, false)
        |> Enum.into(%{})

      {:ok,
       %{
         endpoint: %HLS{
           rtc_engine: options.engine_pid,
           owner: self(),
           output_directory: output_dir(options.room_id, persistent: properties.persistent),
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
           subscribe_mode: result_opts.subscribe_mode
         },
         properties: properties
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def after_init(room_state, component, options) do
    on_hls_startup(room_state.id, component.properties)

    spawn_hls_manager(options)
    :ok
  end

  @impl true
  def on_remove(room_state, component) do
    room_id = room_state.id

    %{low_latency: low_latency} = component.properties

    EtsHelper.delete_hls_folder_path(room_id)

    if low_latency, do: remove_request_handler(room_id)
  end

  @spec output_dir(Room.id(), persistent: boolean()) :: String.t()
  def output_dir(room_id, persistent: true) do
    Recording.directory(room_id)
  end

  def output_dir(room_id, persistent: false) do
    base_path = Application.fetch_env!(:fishjam, :media_files_path)
    Path.join([base_path, "temporary_hls", "#{room_id}"])
  end

  defp on_hls_startup(room_id, %{low_latency: low_latency, persistent: persistent}) do
    room_id
    |> output_dir(persistent: persistent)
    |> then(&EtsHelper.add_hls_folder_path(room_id, &1))

    if low_latency, do: spawn_request_handler(room_id)
  end

  defp spawn_hls_manager(%{engine_pid: engine_pid, room_id: room_id} = options) do
    {:ok, hls_dir} = EtsHelper.get_hls_folder_path(room_id)
    {:ok, valid_opts} = serialize_options(options, Options.schema())

    {:ok, _pid} = Manager.start(room_id, engine_pid, hls_dir, valid_opts)
  end

  defp spawn_request_handler(room_id),
    do: RequestHandler.start(room_id)

  defp remove_request_handler(room_id),
    do: RequestHandler.stop(room_id)

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
end
