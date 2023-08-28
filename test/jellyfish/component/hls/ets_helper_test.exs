defmodule Jellyfish.Component.HLS.EtsHelperTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Jellyfish.Component.HLS.EtsHelper

  @partial <<1, 2, 3>>
  @partial_name "partial_1"
  @wrong_partial_name "partial_101"

  @manifest "manifest"
  @delta_manifest "delta_manifest"

  @recent_partial {1, 1}
  @delta_recent_partial {2, 2}

  @offset 0
  @wrong_offset 1

  @rooms_to_tables :rooms_to_tables

  setup do
    room_id = UUID.uuid4()

    # Ets tables are not removed during tests because they are automatically removed when the owner process dies.
    # Therefore, using on_exit (as a separate process) would cause a crash.
    {:ok, table} = EtsHelper.add_room(room_id)

    %{room_id: room_id, table: table}
  end

  test "rooms managment" do
    room_id = UUID.uuid4()
    assert {:error, :room_not_found} == EtsHelper.get_partial(room_id, @partial_name, @offset)

    {:ok, table} = EtsHelper.add_room(room_id)
    assert {:error, :already_exists} == EtsHelper.add_room(room_id)

    assert [{room_id, table}] == :ets.lookup(@rooms_to_tables, room_id)

    :ok = EtsHelper.remove_room(room_id)
    assert {:error, "Room: #{room_id} doesn't exist"} == EtsHelper.remove_room(room_id)

    assert [] == :ets.lookup(@rooms_to_tables, room_id)
  end

  test "partials managment", %{room_id: room_id, table: table} do
    assert {:error, :file_not_found} == EtsHelper.get_partial(room_id, @partial_name, @offset)

    EtsHelper.add_partial(table, @partial, @partial_name, @offset)

    assert {:ok, @partial} == EtsHelper.get_partial(room_id, @partial_name, @offset)

    assert {:error, :file_not_found} ==
             EtsHelper.get_partial(room_id, @partial_name, @wrong_offset)

    assert {:error, :file_not_found} ==
             EtsHelper.get_partial(room_id, @wrong_partial_name, @offset)

    EtsHelper.delete_partial(table, @partial_name, @offset)

    assert {:error, :file_not_found} == EtsHelper.get_partial(room_id, @partial_name, @offset)
  end

  test "manifests managment", %{room_id: room_id, table: table} do
    assert {:error, :file_not_found} == EtsHelper.get_manifest(room_id)
    assert {:error, :file_not_found} == EtsHelper.get_delta_manifest(room_id)

    EtsHelper.update_manifest(table, @manifest)

    assert {:ok, @manifest} == EtsHelper.get_manifest(room_id)
    assert {:error, :file_not_found} == EtsHelper.get_delta_manifest(room_id)

    EtsHelper.update_delta_manifest(table, @delta_manifest)

    assert {:ok, @manifest} == EtsHelper.get_manifest(room_id)
    assert {:ok, @delta_manifest} == EtsHelper.get_delta_manifest(room_id)
  end

  test "recent partial managment", %{room_id: room_id, table: table} do
    assert {:error, :file_not_found} == EtsHelper.get_recent_partial(room_id)
    assert {:error, :file_not_found} == EtsHelper.get_delta_recent_partial(room_id)

    EtsHelper.update_recent_partial(table, @recent_partial)

    assert {:ok, @recent_partial} == EtsHelper.get_recent_partial(room_id)
    assert {:error, :file_not_found} == EtsHelper.get_delta_recent_partial(room_id)

    EtsHelper.update_delta_recent_partial(table, @delta_recent_partial)

    assert {:ok, @recent_partial} == EtsHelper.get_recent_partial(room_id)
    assert {:ok, @delta_recent_partial} == EtsHelper.get_delta_recent_partial(room_id)
  end
end
