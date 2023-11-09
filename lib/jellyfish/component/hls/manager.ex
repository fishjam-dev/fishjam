defmodule Jellyfish.Component.HLS.Manager do
  @moduledoc """
  Module responsible for HLS processing.
  Responsibilities include: uploading stream to S3, and removing HLS from local memory.
  """

  use GenServer, restart: :temporary
  use Bunch

  require Logger

  alias Jellyfish.Room

  @hls_extensions [".m4s", ".m3u8", ".mp4"]
  @playlist_content_type "application/vnd.apple.mpegurl"

  @spec start(Room.id(), pid(), String.t(), map()) :: :ok
  def start(room_id, engine_pid, hls_dir, hls_options) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Jellyfish.HLS.ManagerSupervisor,
        {__MODULE__,
         %{room_id: room_id, engine_pid: engine_pid, hls_dir: hls_dir, hls_options: hls_options}}
      )

    :ok
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(%{engine_pid: engine_pid, room_id: room_id} = state) do
    Process.monitor(engine_pid)
    Logger.info("Initialize hls manager, room: #{inspect(room_id)}")

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
    Logger.info("Start uploading to s3, room: #{inspect(room_id)}")

    config = create_aws_config(credentials)

    result =
      hls_dir
      |> get_hls_files()
      |> Bunch.Enum.try_each(fn file ->
        content = get_content(hls_dir, file)
        s3_path = get_s3_path(room_id, file)
        opts = get_options(file)

        credentials.bucket
        |> ExAws.S3.put_object(s3_path, content, opts)
        |> ExAws.request(config)
      end)

    Logger.info("End uploading to s3 with result: #{result}, room: #{inspect(room_id)}")
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
    Logger.info("Remove hls from local memory, room: #{inspect(room_id)}")
  end
end
