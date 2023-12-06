defmodule Jellyfish.Component.HLS.Recording do
  @moduledoc false

  alias Jellyfish.Component.HLS.EtsHelper
  alias Jellyfish.Room
  alias Jellyfish.Utils

  @recordings_folder "recordings"

  @spec exists?(Room.id()) :: boolean()
  def exists?(id) do
    path = directory(id)

    if Utils.inside_directory?(path, root_directory()),
      do: File.exists?(path) and not live_stream?(id),
      else: false
  end

  @spec list_all() :: {:ok, [Room.id()]} | :error
  def list_all() do
    case File.ls(root_directory()) do
      {:ok, files} -> {:ok, Enum.filter(files, &exists?(&1))}
      {:error, :enoent} -> {:ok, []}
      {:error, _reason} -> :error
    end
  end

  @spec delete(Room.id()) :: :ok | :error
  def delete(id) do
    if exists?(id), do: do_delete(id), else: :error
  end

  @spec directory(Room.id()) :: String.t()
  def directory(id) do
    root_directory() |> Path.join(id) |> Path.expand()
  end

  defp root_directory() do
    Application.fetch_env!(:jellyfish, :output_base_path)
    |> Path.join(@recordings_folder)
    |> Path.expand()
  end

  defp live_stream?(id) do
    case EtsHelper.get_hls_folder_path(id) do
      {:ok, _path} -> true
      {:error, :room_not_found} -> false
    end
  end

  defp do_delete(id) do
    directory(id) |> File.rm_rf!()
    :ok
  end
end
