defmodule Fishjam.Component.HLS.RequestHandlerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Fishjam.Component.HLS
  alias Fishjam.Component.HLS.{EtsHelper, RequestHandler}

  @wrong_room_id "321"

  @manifest "index.m3u8"
  @wrong_manifest "wrong.m3u8"
  @manifest_content "manifest"

  @partial {1, 1}
  @partial_name "partial"
  @partial_content <<1, 2, 3>>

  @next_partial {1, 2}
  @next_partial_name "muxed_segment_1_g2QABXZpZGVv_2_part.m4s"
  @next_partial_content <<1, 2, 3, 4>>

  @future_partial_name "muxed_segment_1_g2QABXZpZGVv_4_part.m4s"

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

  test "file request - live stream", %{room_id: room_id} do
    add_mock_manifest(room_id, persistent: false)

    assert {:ok, @manifest_content} == RequestHandler.handle_file_request(room_id, @manifest)

    # Non persistent live streams and recordings resides in different folders
    assert {:error, :not_found} ==
             RequestHandler.handle_recording_request(room_id, @manifest)

    assert {:error, :enoent} == RequestHandler.handle_file_request(room_id, @wrong_manifest)

    assert {:error, :room_not_found} ==
             RequestHandler.handle_file_request(@wrong_room_id, @manifest)

    remove_mock_manifest(room_id, persistent: false)
  end

  test "file request - recordings", %{room_id: room_id} do
    add_mock_manifest(room_id, persistent: true)

    # Persistent live streams reside in the same directory as recordings.
    # Nevertheless, the `RequestHandler` is capable of differentiating between them
    assert {:error, :not_found} ==
             RequestHandler.handle_recording_request(room_id, @manifest)

    assert {:ok, @manifest_content} == RequestHandler.handle_file_request(room_id, @manifest)

    # When a room or HLS endpoint finishes, the corresponding path is removed from ETS.
    # This implies that from this point the HLS stream becomes a recording.
    EtsHelper.delete_hls_folder_path(room_id)

    assert {:ok, @manifest_content} == RequestHandler.handle_recording_request(room_id, @manifest)
    assert {:error, :room_not_found} == RequestHandler.handle_file_request(room_id, @manifest)

    assert {:ok, @manifest_content}

    remove_mock_manifest(room_id, persistent: true)
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

    assert nil == Task.yield(task, 500)

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

    assert nil == Task.yield(task, 500)

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

  test "preload hint request", %{room_id: room_id} do
    {:ok, table} = EtsHelper.add_room(room_id)

    EtsHelper.add_partial(table, @partial_content, @partial_name)
    EtsHelper.update_recent_partial(table, @partial)
    RequestHandler.update_recent_partial(room_id, @partial)

    task =
      Task.async(fn -> RequestHandler.handle_partial_request(room_id, @next_partial_name) end)

    assert nil == Task.yield(task, 500)

    EtsHelper.add_partial(table, @next_partial_content, @next_partial_name)
    RequestHandler.update_recent_partial(room_id, @next_partial)

    assert {:ok, @next_partial_content} == Task.await(task)

    assert {:error, :file_not_found} ==
             RequestHandler.handle_partial_request(room_id, @future_partial_name)
  end

  defp add_mock_manifest(room_id, persistent: persistent) do
    path = HLS.output_dir(room_id, persistent: persistent)
    File.mkdir_p!(path)

    path
    |> Path.join(@manifest)
    |> File.write!(@manifest_content)

    EtsHelper.add_hls_folder_path(room_id, path)
  end

  defp remove_mock_manifest(room_id, persistent: persistent) do
    room_id
    |> HLS.output_dir(persistent: persistent)
    |> :file.del_dir_r()

    EtsHelper.delete_hls_folder_path(room_id)
  end
end
