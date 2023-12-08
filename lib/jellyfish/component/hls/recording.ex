defmodule Jellyfish.Component.HLS.Recording do
  @moduledoc false

  alias Jellyfish.Component.HLS.EtsHelper
  alias Jellyfish.Room
  alias Jellyfish.Utils.PathValidation

  @recordings_folder "recordings"

  @spec validate_recording(Room.id()) :: :ok | {:error, :not_found} | {:error, :invalid_recording}
  def validate_recording(id) do
    path = directory(id)

    cond do
      not PathValidation.inside_directory?(path, root_directory()) -> {:error, :invalid_recording}
      exists?(id) -> :ok
      true -> {:error, :not_found}
    end
  end

  @spec list_all() :: {:ok, [Room.id()]} | :error
  def list_all() do
    case File.ls(root_directory()) do
      {:ok, files} -> {:ok, Enum.filter(files, &exists?(&1))}
      {:error, :enoent} -> {:ok, []}
      {:error, _reason} -> :error
    end
  end

  @spec delete(Room.id()) :: :ok | {:error, :not_found} | {:error, :invalid_recording}
  def delete(id) do
    with :ok <- validate_recording(id) do
      do_delete(id)
    end
  end

  @spec directory(Room.id()) :: String.t()
  def directory(id) do
    root_directory() |> Path.join(id) |> Path.expand()
  end

  defp exists?(id) do
    path = directory(id)
    File.exists?(path) and not live_stream?(id)
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
