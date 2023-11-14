defmodule Jellyfish.Component.HLS.Manager do
  @moduledoc """
  Module responsible for HLS processing.
  It:
  * uploads HLS playlist to S3
  * removes HLS playlist from a disk
  """

  use GenServer, restart: :temporary
  use Bunch

  require Logger

  alias Jellyfish.Room

  @hls_extensions [".m4s", ".m3u8", ".mp4"]
  @playlist_content_type "application/vnd.apple.mpegurl"

  @type options :: %{
          room_id: Room.id(),
          engine_pid: pid(),
          hls_dir: String.t(),
          hls_options: map()
        }

  @spec start(Room.id(), pid(), String.t(), map()) :: {:ok, pid()} | {:error, term()}
  def start(room_id, engine_pid, hls_dir, hls_options) do
    DynamicSupervisor.start_child(
      Jellyfish.HLS.ManagerSupervisor,
      {__MODULE__,
       %{room_id: room_id, engine_pid: engine_pid, hls_dir: hls_dir, hls_options: hls_options}}
    )
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(%{engine_pid: engine_pid, room_id: room_id} = state) do
    Process.monitor(engine_pid)
    Logger.info("Initialize hls manager, room: #{room_id}")

    {:ok, state}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, engine_pid, _reason},
        %{engine_pid: engine_pid, hls_options: hls_options, hls_dir: hls_dir, room_id: room_id} =
          state
      ) do
    unless is_nil(hls_options.s3), do: upload_to_s3(hls_dir, room_id, hls_options.s3)
    unless hls_options.persistent, do: remove_hls(hls_dir, room_id)

    {:stop, :normal, state}
  end

  defp upload_to_s3(hls_dir, room_id, credentials) do
    Logger.info("Start uploading to s3, room: #{room_id}")

    config = create_aws_config(credentials)

    result =
      hls_dir
      |> get_hls_files()
      |> Bunch.Enum.try_each(fn file ->
        content = get_content(hls_dir, file)
        s3_path = get_s3_path(room_id, file)
        opts = get_options(file)

        upload_file_to_s3(content, s3_path, opts, config, credentials)
      end)

    Logger.info("Finished uploading to s3 with result: #{result}, room: #{room_id}")
  end

  defp upload_file_to_s3(content, s3_path, opts, config, credentials) do
    result =
      credentials.bucket
      |> ExAws.S3.put_object(s3_path, content, opts)
      |> ExAws.request(config)

    case result do
      {:ok, _value} -> :ok
      error -> error
    end
  end

  defp get_hls_files(hls_dir) do
    hls_dir
    |> File.ls!()
    |> Enum.filter(fn file -> String.ends_with?(file, @hls_extensions) end)
  end

  defp create_aws_config(credentials) do
    credentials
    |> Enum.reject(fn {key, _value} -> key == :bucket end)
    |> then(&ExAws.Config.new(:s3, &1))
    |> Map.to_list()
  end

  defp get_content(hls_dir, file) do
    {:ok, content} = hls_dir |> Path.join(file) |> File.read()
    content
  end

  defp get_options(file) do
    if String.ends_with?(file, ".m3u8"),
      do: [content_type: @playlist_content_type],
      else: []
  end

  defp get_s3_path(room_id, file), do: Path.join(room_id, file)

  defp remove_hls(hls_dir, room_id) do
    File.rm_rf!(hls_dir)
    Logger.info("Remove hls from a disk, room: #{room_id}")
  end
end
