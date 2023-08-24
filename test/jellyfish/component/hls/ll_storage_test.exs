defmodule Jellyfish.Component.HLS.LLStorageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jellyfish.Component.HLS.{EtsHelper, LLStorage, RequestHandler}

  @segment_name "segment"
  @segment_content <<1, 2, 3>>

  @partial_name "partial_segment"
  @partial_content <<1, 2, 3, 4>>
  @partial_sn {0, 0}

  @manifest_name "manifest"
  @manifest_content "manifest_content"

  @delta_manifest_name "manifest_delta.m3u8"
  @delta_manifest_content "delta_manifest_content"

  @header_name "header"
  @header_content <<1, 2, 3, 4, 5>>

  setup %{tmp_dir: tmp_dir} do
    room_id = UUID.uuid4()
    directory = Path.join(tmp_dir, room_id)

    File.mkdir_p!(directory)

    config = %LLStorage{directory: directory, room_id: room_id}

    storage = LLStorage.init(config)
    {:ok, _pid} = RequestHandler.start(room_id)

    %{storage: storage, directory: directory, room_id: room_id}
  end

  @tag :tmp_dir
  test "store segment", %{storage: storage, directory: directory} do
    {:ok, _storage} = store_segment(storage)

    segment_path = Path.join(directory, @segment_name)
    assert {:error, :enoent} == File.read(segment_path)
  end

  @tag :tmp_dir
  test "store partial", %{storage: storage, directory: directory, room_id: room_id} do
    {:ok, _storage} = store_partial(storage)

    partial_path = Path.join(directory, @partial_name)
    assert {:ok, @partial_content} == File.read(partial_path)

    assert {:ok, @partial_content} == EtsHelper.get_partial(room_id, @partial_name, 0)
  end

  @tag :tmp_dir
  test "store manifest", %{storage: storage, directory: directory, room_id: room_id} do
    {:ok, storage} = store_partial(storage)
    {:ok, _storage} = store_manifest(storage)

    assert {:ok, @manifest_content} == EtsHelper.get_manifest(room_id)
    assert {:ok, @partial_sn} == EtsHelper.get_recent_partial(room_id)

    manifest_path = Path.join(directory, @manifest_name)
    assert {:ok, @manifest_content} == File.read(manifest_path)

    pid = self()

    spawn(fn ->
      {:ok, @manifest_content} = RequestHandler.handle_manifest_request(room_id, @partial_sn)
      send(pid, :manifest)
    end)

    assert_receive(:manifest)
  end

  @tag :tmp_dir
  @tag timeout: 1_000
  test "store delta manifest", %{storage: storage, directory: directory, room_id: room_id} do
    {:ok, storage} = store_partial(storage)
    {:ok, _storage} = store_delta_manifest(storage)

    assert {:ok, @delta_manifest_content} == EtsHelper.get_delta_manifest(room_id)
    assert {:ok, @partial_sn} == EtsHelper.get_delta_recent_partial(room_id)

    manifest_path = Path.join(directory, @delta_manifest_name)
    assert {:ok, @delta_manifest_content} == File.read(manifest_path)

    assert {:ok, @delta_manifest_content} ==
             RequestHandler.handle_delta_manifest_request(room_id, @partial_sn)
  end

  @tag :tmp_dir
  test "store header", %{storage: storage, directory: directory} do
    {:ok, _storage} = store_header(storage)

    header_path = Path.join(directory, @header_name)
    assert {:ok, @header_content} == File.read(header_path)
  end

  defp store_segment(storage) do
    LLStorage.store(
      :parent_id,
      @segment_name,
      @segment_content,
      :metadata,
      %{mode: :binary, type: :segment},
      storage
    )
  end

  defp store_partial(storage) do
    LLStorage.store(
      :parent_id,
      @partial_name,
      @partial_content,
      %{byte_offset: 0, sequence_number: 0},
      %{mode: :binary, type: :partial_segment},
      storage
    )
  end

  defp store_manifest(storage) do
    LLStorage.store(
      :parent_id,
      @manifest_name,
      @manifest_content,
      :metadata,
      %{mode: :text, type: :manifest},
      storage
    )
  end

  defp store_delta_manifest(storage) do
    LLStorage.store(
      :parent_id,
      @delta_manifest_name,
      @delta_manifest_content,
      :metadata,
      %{mode: :text, type: :manifest},
      storage
    )
  end

  defp store_header(storage) do
    LLStorage.store(
      :parent_id,
      @header_name,
      @header_content,
      :metadata,
      %{mode: :binary, type: :header},
      storage
    )
  end
end
