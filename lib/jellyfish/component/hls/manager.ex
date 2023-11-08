defmodule Jellyfish.Component.HLS.Manager do
  @moduledoc """
  Module responsible for HLS processing.
  """

  use GenServer

  require Logger

  alias Jellyfish.Room

  @hls_extensions [".m4s", ".m3u8", ".mp4"]
  @playlist_content_type "application/vnd.apple.mpegurl"

  @spec start(Room.id(), pid(), String.t(), map()) :: :ok
  def start(room_id, engine_pid, hls_dir, hls_options) do
    {:ok, _pid} = GenServer.start(__MODULE__, [room_id, engine_pid, hls_dir, hls_options])
    :ok
  end

  @impl true
  def init([room_id, engine_pid, hls_dir, hls_options]) do
    Process.monitor(engine_pid)
    Logger.info("Initialize s3 uploader")

    {:ok, %{room_id: room_id, engine_pid: engine_pid, hls_dir: hls_dir, hls_options: hls_options}}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, engine_pid, _reason},
        %{engine_pid: engine_pid} = state
      ) do
    unless is_nil(state.hls_options.s3) do
      state.hls_options.s3
      |> create_aws_config()
      |> upload_to_s3(state.hls_dir, state.hls_options.s3.bucket, state.room_id)
    end

    maybe_remove_hls(state.hls_options, state.hls_dir)

    {:stop, :normal, state}
  end

  defp upload_to_s3(config, hls_dir, bucket, room_id) do
    hls_dir
    |> get_hls_files()
    |> Enum.each(fn file ->
      content = get_content(hls_dir, file)
      s3_path = get_s3_path(room_id, file)
      opts = get_options(file)

      bucket
      |> ExAws.S3.put_object(s3_path, content, opts)
      |> ExAws.request(config)
    end)
  end

  defp maybe_remove_hls(%{persistent: false}, hls_dir), do: remove_hls(hls_dir)
  defp maybe_remove_hls(%{persistent: true}, _hls_dir), do: nil

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

  defp remove_hls(hls_dir), do: File.rm_rf!(hls_dir)
end
