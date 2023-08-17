defmodule Jellyfish.Component.HLS.EtsHelper do
  @moduledoc false

  alias Jellyfish.Room

  @rooms_to_tabels :rooms_to_tables
  @free_tables :free_tables

  @last_partial_key :last_partial
  @manifest_key :manifest

  @delta_last_partial_key :delta_last_partial
  @delta_manifest_key :delta_manifest

  @type partial :: {non_neg_integer(), non_neg_integer()}

  def get_partial(room_id, filename, offset) do
    table = get_table(room_id)
    key = generate_partial_key(filename, offset)
    [{^key, partial}] = :ets.lookup(table, key)
    {:ok, partial}
  end

  def get_last_partial(room_id, filename) do
    table = get_table(room_id)

    [{_key, last_partial}] =
      if String.contains?(filename, "_delta.m3u8"),
        do: :ets.lookup(table, @delta_last_partial_key),
        else: :ets.lookup(table, @last_partial_key)

    last_partial
  end

  def get_manifest(room_id, filename) do
    table = get_table(room_id)

    [{_key, manifest}] =
      if String.contains?(filename, "_delta.m3u8"),
        do: :ets.lookup(table, @delta_manifest_key),
        else: :ets.lookup(table, @manifest_key)

    manifest
  end

  @spec add_last_partial(Room.id(), partial()) :: true
  def add_last_partial(room_id, last_partial) do
    table = get_table(room_id)
    :ets.insert(table, {@last_partial_key, last_partial})
  end

  @spec add_last_partial(Room.id(), partial()) :: true
  def add_delta_last_partial(room_id, delta_last_partial) do
    table = get_table(room_id)
    :ets.insert(table, {@delta_last_partial_key, delta_last_partial})
  end

  @spec add_delta_manifest(Room.id(), String.t()) :: true
  def add_delta_manifest(room_id, delta_manifest) do
    table = get_table(room_id)
    :ets.insert(table, {@delta_manifest_key, delta_manifest})
  end

  @spec add_manifest(Room.id(), String.t()) :: true
  def add_manifest(room_id, manifest) do
    table = get_table(room_id)
    :ets.insert(table, {@manifest_key, manifest})
  end

  @spec remove_partial(Room.id(), String.t(), non_neg_integer()) :: true
  def remove_partial(room_id, filename, offset) do
    table = get_table(room_id)
    key = generate_partial_key(filename, offset)
    :ets.delete(table, key)
  end

  @spec add_partial(Room.id(), binary(), String.t(), non_neg_integer()) :: true
  def add_partial(room_id, partial, filename, offset) do
    table = get_table(room_id)
    key = generate_partial_key(filename, offset)
    :ets.insert(table, {key, partial})
  end

  @spec remove_room(Room.id()) :: :ok | {:error, :not_exists}
  def remove_room(room_id) do
    case :ets.lookup(@rooms_to_tabels, room_id) do
      [{^room_id, table}] ->
        add_to_free_tables(table)
        :ets.delete(@rooms_to_tabels, room_id)
        :ok

      _empty ->
        {:error, :not_exists}
    end
  end

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
