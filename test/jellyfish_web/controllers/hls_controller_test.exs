defmodule JellyfishWeb.HLSControllerTest do
  use JellyfishWeb.ConnCase, async: true

  alias Jellyfish.Component.HLS
  alias Jellyfish.Component.HLS.{EtsHelper, RequestHandler}

  @room_id "hls_controller_test"
  @wrong_room_id "wrong_id"

  @header_name "header_name.mp4"
  @header_content <<1>>

  @segment_name "segment_name.m4s"
  @segment_content <<2>>

  @manifest_name "manifest_name.m3u8"
  @manifest_content <<3>>
  @delta_manifest_content <<4>>

  @master_manifest_name "index.m3u8"
  @master_manifest_content <<5>>

  @partial_name "partial_name.m4s"
  @partial_content <<6>>
  @partial_sn {0, 0}
  @offset 0
  @wrong_offset 50

  setup_all do
    output_path = HLS.output_dir(@room_id)
    File.mkdir_p!(output_path)

    prepare_files(output_path)
    prepare_ets()
    prepare_request_handler()

    on_exit(fn -> :file.del_dir_r(output_path) end)
  end

  test "request master manifest", %{conn: conn} do
    conn1 = get(conn, ~p"/hls/#{@room_id}/#{@master_manifest_name}")
    assert @master_manifest_content == response(conn1, 200)

    conn2 = get(conn, ~p"/hls/#{@wrong_room_id}/#{@master_manifest_name}")
    response(conn2, 404)

    conn3 = get(conn, ~p"/hls/#{@room_id}/wrong_name.m3u8")
    response(conn3, 404)
  end

  test "request header", %{conn: conn} do
    conn1 = get(conn, ~p"/hls/#{@room_id}/#{@header_name}")
    assert @header_content == response(conn1, 200)

    conn2 = get(conn, ~p"/hls/#{@wrong_room_id}/#{@header_name}")
    assert response(conn2, 404)

    conn3 = get(conn, ~p"/hls/#{@room_id}/wrong_name.mp4")
    assert response(conn3, 404)
  end

  test "request segment", %{conn: conn} do
    conn1 = get(conn, ~p"/hls/#{@room_id}/#{@segment_name}")
    assert @segment_content == response(conn1, 200)

    conn2 = get(conn, ~p"/hls/#{@wrong_room_id}/#{@segment_name}")
    assert response(conn2, 404)

    conn3 = get(conn, ~p"/hls/#{@room_id}/wrong_name.m4s")
    assert response(conn3, 404)
  end

  test "request partial", %{conn: conn} do
    conn1 =
      conn
      |> put_req_header("range", "bytes=#{@offset}-100")
      |> get(~p"/hls/#{@room_id}/#{@partial_name}")

    assert @partial_content == response(conn1, 200)

    conn2 =
      conn
      |> put_req_header("range", "bytes=#{@wrong_offset}-100")
      |> get(~p"/hls/#{@room_id}/#{@partial_name}")

    assert response(conn2, 404)

    conn3 =
      conn
      |> get(~p"/hls/#{@wrong_room_id}/#{@partial_name}")

    assert response(conn3, 404)

    conn4 =
      conn
      |> get(~p"/hls/#{@room_id}/wrong_name.m4s")

    assert response(conn4, 404)
  end

  test "request manifest", %{conn: conn} do
    conn1 = get(conn, ~p"/hls/#{@room_id}/#{@manifest_name}")
    assert @manifest_content == response(conn1, 200)

    conn2 = get(conn, ~p"/hls/#{@wrong_room_id}/#{@manifest_name}")
    response(conn2, 404)

    conn3 = get(conn, ~p"/hls/#{@room_id}/wrong_name.m3u8")
    response(conn3, 404)
  end

  test "request ll-manifest", %{conn: conn} do
    conn1 =
      get(conn, ~p"/hls/#{@room_id}/#{@manifest_name}", %{
        "room_id" => @room_id,
        "_HLS_msn" => 0,
        "_HLS_part" => 0
      })

    assert @manifest_content == response(conn1, 200)
  end

  test "request ll-delta-manifest", %{conn: conn} do
    conn =
      get(conn, ~p"/hls/#{@room_id}/#{@manifest_name}", %{
        "_HLS_skip" => true,
        "room_id" => @room_id,
        "_HLS_msn" => 0,
        "_HLS_part" => 0
      })

    assert @delta_manifest_content == response(conn, 200)
  end

  defp prepare_files(output_path) do
    header_path = Path.join(output_path, @header_name)
    File.write!(header_path, @header_content)

    manifest_path = Path.join(output_path, @manifest_name)
    File.write!(manifest_path, @manifest_content)

    segment_path = Path.join(output_path, @segment_name)
    File.write!(segment_path, @segment_content)

    master_manifest_path = Path.join(output_path, @master_manifest_name)
    File.write!(master_manifest_path, @master_manifest_content)
  end

  defp prepare_ets() do
    {:ok, table} = EtsHelper.add_room(@room_id)

    EtsHelper.add_partial(table, @partial_content, @partial_name, @offset)
    EtsHelper.update_recent_partial(table, @partial_sn)
    EtsHelper.update_delta_recent_partial(table, @partial_sn)
    EtsHelper.update_manifest(table, @manifest_content)
    EtsHelper.update_delta_manifest(table, @delta_manifest_content)
  end

  defp prepare_request_handler() do
    {:ok, _pid} = RequestHandler.start(@room_id)

    RequestHandler.update_recent_partial(@room_id, @partial_sn)
    RequestHandler.update_delta_recent_partial(@room_id, @partial_sn)
  end
end
