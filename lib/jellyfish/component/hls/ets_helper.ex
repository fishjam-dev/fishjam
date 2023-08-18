defmodule Jellyfish.Component.HLS.EtsHelper do
  @moduledoc false

  alias Jellyfish.Room

  @rooms_to_tabels :rooms_to_tables
  @free_tables :free_tables

  @recent_partial_key :recent_partial
  @manifest_key :manifest

  @delta_recent_partial_key :delta_recent_partial
  @delta_manifest_key :delta_manifest

  @type partial :: {non_neg_integer(), non_neg_integer()}

  ###
  ### ROOM MANAGMENT
  ###

  @spec add_room(Room.id()) :: :ok | {:error, :already_exists}
  def add_room(room_id) do
    cond do
      room_exists?(room_id) ->
        {:error, :already_exists}

      free_table_exists?() ->
        table = get_free_table()
        add_room(room_id, table)
        :ok

      true ->
        table = generate_table()
        add_room(room_id, table)
        :ok
    end
  end

  @spec remove_room(Room.id()) :: :ok | {:error, String.t()}
  def remove_room(room_id) do
    case :ets.lookup(@rooms_to_tabels, room_id) do
      [{^room_id, table}] ->
        add_to_free_tables(table)
        :ets.delete(table)
        :ets.delete(@rooms_to_tabels, room_id)
        :ok

      _empty ->
        {:error, "Room: #{room_id} doesn't exist"}
    end
  end

  ###
  ### ETS CONTENT MANAGMENT
  ###

  @spec update_manifest(Room.id(), String.t()) :: true
  def update_manifest(room_id, manifest) do
    object = {@manifest_key, manifest}
    add_to_ets(room_id, object)
  end

  @spec update_delta_manifest(Room.id(), String.t()) :: true
  def update_delta_manifest(room_id, delta_manifest) do
    object = {@delta_manifest_key, delta_manifest}
    add_to_ets(room_id, object)
  end

  @spec update_recent_partial(Room.id(), partial()) :: true
  def update_recent_partial(room_id, partial) do
    object = {@recent_partial_key, partial}
    add_to_ets(room_id, object)
  end

  @spec update_delta_recent_partial(Room.id(), partial()) :: true
  def update_delta_recent_partial(room_id, partial) do
    object = {@delta_recent_partial_key, partial}
    add_to_ets(room_id, object)
  end

  @spec add_partial(Room.id(), binary(), String.t(), non_neg_integer()) :: true
  def add_partial(room_id, partial, filename, offset) do
    key = generate_partial_key(filename, offset)
    object = {key, partial}
    add_to_ets(room_id, object)
  end

  @spec delete_partial(Room.id(), String.t(), non_neg_integer()) :: true
  def delete_partial(room_id, filename, offset) do
    table = get_table(room_id)
    key = generate_partial_key(filename, offset)
    :ets.delete(table, key)
  end

  ###
  ### ETS GETTERS
  ###

  @spec get_partial(Room.id(), String.t(), non_neg_integer()) ::
          {:ok, binary()} | {:error, :not_found}
  def get_partial(room_id, filename, offset) do
    key = generate_partial_key(filename, offset)
    get_from_ets(room_id, key)
  end

  @spec get_recent_partial(Room.id()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :not_found}
  def get_recent_partial(room_id) do
    get_from_ets(room_id, @recent_partial_key)
  end

  @spec get_delta_recent_partial(Room.id()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :not_found}
  def get_delta_recent_partial(room_id) do
    get_from_ets(room_id, @delta_recent_partial_key)
  end

  @spec get_manifest(Room.id()) :: {:ok, String.t()} | {:error, :not_found}
  def get_manifest(room_id) do
    get_from_ets(room_id, @manifest_key)
  end

  @spec get_delta_manifest(Room.id()) :: {:ok, String.t()} | {:error, :not_found}
  def get_delta_manifest(room_id) do
    get_from_ets(room_id, @delta_manifest_key)
  end

  ###
  ### PRIVATE FUNCTIONS
  ###

  defp add_to_ets(room_id, object) do
    table = get_table(room_id)
    :ets.insert(table, object)
  end

  def get_from_ets(room_id, key) do
    table = get_table(room_id)

    case :ets.lookup(table, key) do
      [{^key, manifest}] -> {:ok, manifest}
      [] -> {:error, :not_found}
    end
  end

  defp get_table(room_id) do
    case :ets.lookup(@rooms_to_tabels, room_id) do
      [{^room_id, table}] -> table
      _empty -> {:error, :not_exists}
    end
  end

  defp add_to_free_tables(table) do
    [{@free_tables, free_tables}] = :ets.lookup(@rooms_to_tabels, @free_tables)
    :ets.insert(@rooms_to_tabels, {@free_tables, [table | free_tables]})
  end

  defp room_exists?(room_id) do
    if :ets.lookup(@rooms_to_tabels, room_id) == [], do: false, else: true
  end

  defp free_table_exists?() do
    [{@free_tables, free_tables}] = :ets.lookup(@rooms_to_tabels, @free_tables)
    if free_tables == [], do: false, else: true
  end

  defp get_free_table() do
    [{@free_tables, free_tables}] = :ets.lookup(@rooms_to_tabels, @free_tables)
    [table | rest] = free_tables
    :ets.insert(@rooms_to_tabels, {@free_tables, rest})
    table
  end

  defp add_room(room_id, table) do
    :ets.insert(@rooms_to_tabels, {room_id, table})
    :ets.new(table, [:public, :set, :named_table])
  end

  defp generate_table() do
    table = String.to_atom(UUID.uuid1())
    if table_exists?(table), do: generate_table(), else: table
  end

  defp table_exists?(table) do
    @rooms_to_tabels
    |> :ets.tab2list()
    |> Enum.all?(fn {_key, value} -> value != table end)
    |> Kernel.not()
  end

  defp generate_partial_key(filename, offset), do: "#{filename}_#{offset}"
end
