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

  @spec list_all() :: [Room.id()]
  def list_all() do
    root_directory()
    |> File.ls!()
    |> Enum.filter(&exists?(&1))
  end

  @spec delete(Room.id()) :: :ok
  def delete(id) do
    directory(id) |> File.rm_rf!()
    :ok
  end

  @spec directory(Room.id()) :: String.t()
  def directory(id) do
    root_directory() |> Path.join(id)
  end

  defp root_directory() do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    Path.join([base_path, "recordings"])
  end
end
