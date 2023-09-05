defmodule Jellyfish.Component.HLS.RequestHandlerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jellyfish.Component.HLS
  alias Jellyfish.Component.HLS.{EtsHelper, RequestHandler}

  @wrong_room_id "321"

  @manifest "index.m3u8"
  @wrong_manifest "wrong.m3u8"
  @manifest_content "manifest"

  @partial {1, 1}
  @next_partial {1, 2}
  @partial_name "partial"
  @partial_content <<1, 2, 3>>

  setup do
    room_id = UUID.uuid4()

    # RequestHandler is not removed at all in tests
    # It removes itself when parent process is killed
    RequestHandler.start(room_id)

    %{room_id: room_id}
  end

  test "room managment", %{room_id: room_id} do
    {:error, {:already_started, _pid}} = RequestHandler.start(room_id)
    {:ok, _table} = EtsHelper.add_room(room_id)

    RequestHandler.stop(room_id)

    # wait for ets to be removed
    Process.sleep(200)

    assert {:error, :room_not_found} == EtsHelper.get_manifest(room_id)

    assert {:ok, _pid} = RequestHandler.start(room_id)
  end

  test "file request", %{room_id: room_id} do
    add_mock_manifest(room_id)

    assert {:ok, @manifest_content} == RequestHandler.handle_file_request(room_id, @manifest)

    assert {:error, :enoent} == RequestHandler.handle_file_request(room_id, @wrong_manifest)
    assert {:error, :enoent} == RequestHandler.handle_file_request(@wrong_room_id, @manifest)

    remove_mock_manifest(room_id)
  end

  test "manifest request", %{room_id: room_id} do
    assert {:error, :room_not_found} == RequestHandler.handle_manifest_request(room_id, @partial)

    {:ok, table} = EtsHelper.add_room(room_id)

    assert {:error, :file_not_found} == RequestHandler.handle_manifest_request(room_id, @partial)

    EtsHelper.update_recent_partial(table, @partial)
    EtsHelper.update_manifest(table, @manifest_content)
    RequestHandler.update_recent_partial(room_id, @partial)

    assert {:ok, @manifest_content} == RequestHandler.handle_manifest_request(room_id, @partial)

    task =
      Task.async(fn ->
        RequestHandler.handle_manifest_request(room_id, @next_partial)
      end)

    assert nil == Task.yield(task)

    RequestHandler.update_recent_partial(room_id, @next_partial)

    assert {:ok, @manifest_content} == Task.await(task)
  end

  test "delta manifest request", %{room_id: room_id} do
    assert {:error, :room_not_found} ==
             RequestHandler.handle_delta_manifest_request(room_id, @partial)

    {:ok, table} = EtsHelper.add_room(room_id)

    assert {:error, :file_not_found} ==
             RequestHandler.handle_delta_manifest_request(room_id, @partial)

    EtsHelper.update_delta_recent_partial(table, @partial)
    EtsHelper.update_delta_manifest(table, @manifest_content)
    RequestHandler.update_delta_recent_partial(room_id, @partial)

    assert {:ok, @manifest_content} ==
             RequestHandler.handle_delta_manifest_request(room_id, @partial)

    task =
      Task.async(fn ->
        RequestHandler.handle_delta_manifest_request(room_id, @next_partial)
      end)

    assert nil == Task.yield(task)

    RequestHandler.update_delta_recent_partial(room_id, @next_partial)

    assert {:ok, @manifest_content} == Task.await(task)
  end

  test "partial request", %{room_id: room_id} do
    assert {:error, :room_not_found} ==
             RequestHandler.handle_partial_request(room_id, @partial_name)

    {:ok, table} = EtsHelper.add_room(room_id)

    assert {:error, :file_not_found} ==
             RequestHandler.handle_partial_request(room_id, @partial_name)

    EtsHelper.add_partial(table, @partial_content, @partial_name)

    assert {:ok, @partial_content} ==
             RequestHandler.handle_partial_request(room_id, @partial_name)

    assert {:error, :file_not_found} ==
             RequestHandler.handle_partial_request(room_id, "wrong_partial_name")
  end

  defp add_mock_manifest(room_id) do
    room_id
    |> HLS.output_dir()
    |> File.mkdir_p!()

    room_id
    |> HLS.output_dir()
    |> Path.join(@manifest)
    |> File.write!(@manifest_content)
  end

  defp remove_mock_manifest(room_id) do
    room_id
    |> HLS.output_dir()
    |> :file.del_dir_r()
  end
end
