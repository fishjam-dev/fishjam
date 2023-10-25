defmodule Jellyfish.Component.HLS.Recording do
  @moduledoc false

  alias Jellyfish.Component.HLS.EtsHelper
  alias Jellyfish.Room

  @spec exists?(Room.id()) :: boolean()
  def exists?(id) do
    with true <- directory(id) |> File.exists?(),
         {:error, :room_not_found} <- EtsHelper.get_hls_folder_path(id) do
      true
    else
      {:ok, _path} -> false
      false -> false
    end
  end

  @spec list_all() :: {:ok, [Room.id()]} | :error
  def list_all() do
    case File.ls(root_directory()) do
      {:ok, files} -> {:ok, Enum.filter(files, &exists?(&1))}
      {:error, _reason} -> :error
    end
  end

  @spec delete(Room.id()) :: :ok | :error
  def delete(id) do
    if exists?(id), do: do_delete(id), else: :error
  end

  @spec directory(Room.id()) :: String.t()
  def directory(id) do
    root_directory() |> Path.join(id)
  end

  defp root_directory() do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    Path.join([base_path, "recordings"])
  end

  defp do_delete(id) do
    directory(id) |> File.rm_rf!()
    :ok
  end
end
