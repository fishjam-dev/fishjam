defmodule JellyfishWeb.RecordingControllerTest do
  use JellyfishWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  doctest Jellyfish.Utils.PathValidation

  alias Jellyfish.Component.HLS
  alias Jellyfish.Component.HLS.{EtsHelper, Recording}

  @recording_id "recording_id"
  @live_stream_id "live_stream_id"
  @for_deleting_id "for_deleting_id"
  @outside_file "../outside_file"
  @outside_manifest "../outside_manifest.m3u8"

  @segment_name "segment_name.m4s"
  @segment_content <<2>>

  @manifest_name "manifest_name.m3u8"
  @wrong_manifest_name "wrong_manifest_name.m3u8"
  @manifest_content <<3>>

  @schema JellyfishWeb.ApiSpec.spec()

  setup_all do
    recording_path = Recording.directory(@recording_id)

    # In case of persistent live stream, the root folder is the same as `recording_path`
    live_stream_path = HLS.output_dir(@live_stream_id, persistent: true)

    prepare_files(recording_path)
    prepare_files(live_stream_path)

    # Live streams are added to ets
    EtsHelper.add_hls_folder_path(@live_stream_id, live_stream_path)

    on_exit(fn ->
      :file.del_dir_r(recording_path)
      :file.del_dir_r(live_stream_path)
    end)
  end

  test "request manifest", %{conn: conn} do
    conn = get(conn, ~p"/recording/#{@recording_id}/#{@manifest_name}")
    assert @manifest_content == response(conn, 200)

    conn
    |> get(~p"/recording/#{@recording_id}/#{@wrong_manifest_name}")
    |> json_response(:not_found)
    |> assert_response_schema("Error", @schema)

    conn
    |> get(~p"/recording/#{@live_stream_id}/#{@manifest_name}")
    |> json_response(:not_found)
    |> assert_response_schema("Error", @schema)
  end

  test "request manifest with invalid filename", %{conn: conn} do
    conn
    |> get(~p"/recording/#{@recording_id}/#{@outside_manifest}")
    |> json_response(:bad_request)
    |> assert_response_schema("Error", @schema)
  end

  test "request manifest with invalid recording", %{conn: conn} do
    conn
    |> get(~p"/recording/#{@outside_file}/#{@manifest_name}")
    |> json_response(:bad_request)
    |> assert_response_schema("Error", @schema)
  end

  test "list of recordings", %{conn: conn} do
    conn = get(conn, ~p"/recording")
    assert @recording_id in json_response(conn, :ok)["data"]
  end

  test "delete recording", %{conn: conn} do
    @for_deleting_id
    |> Recording.directory()
    |> prepare_files()

    conn = get(conn, ~p"/recording")
    assert @for_deleting_id in json_response(conn, :ok)["data"]

    conn = delete(conn, ~p"/recording/#{@for_deleting_id}")
    response(conn, 204)

    conn = get(conn, ~p"/recording")
    assert @for_deleting_id not in json_response(conn, :ok)["data"]

    conn
    |> delete(~p"/recording/#{@for_deleting_id}")
    |> json_response(:not_found)
    |> assert_response_schema("Error", @schema)
  end

  test "delete whole recording directory", %{conn: conn} do
    conn
    |> delete(~p"/recording/.")
    |> json_response(:bad_request)
    |> assert_response_schema("Error", @schema)
  end

  test "delete using invalid filename", %{conn: conn} do
    conn
    |> delete(~p"/recording/#{@outside_file}")
    |> json_response(:bad_request)
    |> assert_response_schema("Error", @schema)
  end

  defp prepare_files(output_path) do
    File.mkdir_p!(output_path)

    manifest_path = Path.join(output_path, @manifest_name)
    File.write!(manifest_path, @manifest_content)

    segment_path = Path.join(output_path, @segment_name)
    File.write!(segment_path, @segment_content)
  end
end
