defmodule Jellyfish.Component.HLS.EtsHelper do
  @moduledoc false

  alias Jellyfish.Room

  @rooms_to_tables :rooms_to_tables

  @recent_partial_key :recent_partial
  @manifest_key :manifest

  @delta_recent_partial_key :delta_recent_partial
  @delta_manifest_key :delta_manifest

  @type partial :: {non_neg_integer(), non_neg_integer()}

  ###
  ### ROOM MANAGMENT
  ###

  @spec add_room(Room.id()) :: {:ok, reference()} | {:error, :already_exists}
  def add_room(room_id) do
    if room_exists?(room_id) do
      {:error, :already_exists}
    else
      # Ets is public because ll-storage can't delete table.
      # If we change that storage can be protected
      table = :ets.new(:hls_storage, [:public])
      :ets.insert(@rooms_to_tables, {room_id, table})
      {:ok, table}
    end
  end

  @spec remove_room(Room.id()) :: :ok | {:error, String.t()}
  def remove_room(room_id) do
    case :ets.lookup(@rooms_to_tables, room_id) do
      [{^room_id, table}] ->
        :ets.delete(table)
        :ets.delete(@rooms_to_tables, room_id)
        :ok

      _empty ->
        {:error, "Room: #{room_id} doesn't exist"}
    end
  end

  ###
  ### ETS CONTENT MANAGMENT
  ###

  @spec update_manifest(:ets.table(), String.t()) :: true
  def update_manifest(table, manifest) do
    :ets.insert(table, {@manifest_key, manifest})
  end

  @spec update_delta_manifest(:ets.table(), String.t()) :: true
  def update_delta_manifest(table, delta_manifest) do
    :ets.insert(table, {@delta_manifest_key, delta_manifest})
  end

  @spec update_recent_partial(:ets.table(), partial()) :: true
  def update_recent_partial(table, partial) do
    :ets.insert(table, {@recent_partial_key, partial})
  end

  @spec update_delta_recent_partial(:ets.table(), partial()) :: true
  def update_delta_recent_partial(table, partial) do
    :ets.insert(table, {@delta_recent_partial_key, partial})
  end

  @spec add_partial(:ets.table(), binary(), String.t(), non_neg_integer()) :: true
  def add_partial(table, partial, filename, offset) do
    key = generate_partial_key(filename, offset)
    :ets.insert(table, {key, partial})
  end

  @spec delete_partial(:ets.table(), String.t(), non_neg_integer()) :: true
  def delete_partial(table, filename, offset) do
    key = generate_partial_key(filename, offset)
    :ets.delete(table, key)
  end

  ###
  ### ETS GETTERS
  ###

  @spec get_partial(Room.id(), String.t(), non_neg_integer()) ::
          {:ok, binary()} | {:error, atom()}
  def get_partial(room_id, filename, offset) do
    key = generate_partial_key(filename, offset)
    get_from_ets(room_id, key)
  end

  @spec get_recent_partial(Room.id()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, atom()}
  def get_recent_partial(room_id) do
    get_from_ets(room_id, @recent_partial_key)
  end

  @spec get_delta_recent_partial(Room.id()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, atom()}
  def get_delta_recent_partial(room_id) do
    get_from_ets(room_id, @delta_recent_partial_key)
  end

  @spec get_manifest(Room.id()) :: {:ok, String.t()} | {:error, atom()}
  def get_manifest(room_id) do
    get_from_ets(room_id, @manifest_key)
  end

  @spec get_delta_manifest(Room.id()) :: {:ok, String.t()} | {:error, atom()}
  def get_delta_manifest(room_id) do
    get_from_ets(room_id, @delta_manifest_key)
  end

  ###
  ### PRIVATE FUNCTIONS
  ###

  def get_from_ets(room_id, key) do
    with {:ok, table} <- get_table(room_id) do
      lookup_ets(table, key)
    end
  end

  defp lookup_ets(table, key) do
    case :ets.lookup(table, key) do
      [{^key, val}] -> {:ok, val}
      [] -> {:error, :file_not_found}
    end
  end

  defp get_table(room_id) do
    case :ets.lookup(@rooms_to_tables, room_id) do
      [{^room_id, table}] -> {:ok, table}
      _empty -> {:error, :room_not_found}
    end
  end

  defp room_exists?(room_id) do
    :ets.lookup(@rooms_to_tables, room_id) != []
  end

  defp generate_partial_key(filename, offset), do: "#{filename}_#{offset}"
end
