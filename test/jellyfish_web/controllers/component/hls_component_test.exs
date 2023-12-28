defmodule JellyfishWeb.Component.HlsComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  import Mox

  alias Jellyfish.RoomService

  alias Jellyfish.Component.HLS

  @files ["manifest.m3u8", "header.mp4", "segment_1.m3u8", "segment_2.m3u8"]
  @body <<1, 2, 3, 4>>

  @hls_properties %{
    playable: false,
    lowLatency: false,
    persistent: false,
    targetWindowDuration: nil,
    subscribeMode: "auto",
    s3: nil
  } |> map_keys_to_string()

  describe "create hls component" do
    setup [:create_h264_room]

    test "renders component when data is valid, allows max 1 hls per room", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "hls",
                 "properties" => @hls_properties
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "hls")

      assert_hls_path(room_id, persistent: false)

      # Try to add another hls component
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Reached components limit for component HLS in room #{room_id}"

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)
      assert_no_hls_path(room_id)
    end

    test "renders component with peristent enabled", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls", options: %{persistent: true})

      properties = @hls_properties |> Map.put("persistent", true)

      assert %{"data" => %{"type" => "hls", "properties" => ^properties}} =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_hls_path(room_id, persistent: true)

      # It is persistent stream so we have to remove it manually
      assert {:ok, _removed_files} = room_id |> HLS.Recording.directory() |> File.rm_rf()
    end

    setup :set_mox_from_context
    setup :verify_on_exit!

    test "renders component with s3 credentials", %{conn: conn, room_id: room_id} do
      bucket = "bucket"

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "hls",
          options: %{
            persistent: false,
            s3: %{
              accessKeyId: "access_key_id",
              secretAccessKey: "secret_access_key",
              region: "region",
              bucket: bucket
            }
          }
        )

      assert %{
               "data" => %{
                 "type" => "hls",
                 "properties" => @hls_properties
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      parent = self()
      ref = make_ref()

      expect(ExAws.Request.HttpMock, :request, 4, fn _method,
                                                     url,
                                                     req_body,
                                                     _headers,
                                                     _http_opts ->
        assert req_body == @body
        assert String.contains?(url, bucket)
        assert String.ends_with?(url, @files)

        send(parent, {ref, :request})
        {:ok, %{status_code: 200, headers: %{}}}
      end)

      assert_hls_path(room_id, persistent: false)

      # waits for directory to be created
      # then adds 4 files to it
      add_files_for_s3_upload(room_id)

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)

      # above we created 4 files
      # so there should be axactly 4 requests
      for _ <- 1..4, do: assert_receive({^ref, :request}, 10_000)
    end

    test "renders component with targetWindowDuration set", %{conn: conn, room_id: room_id} do
      target_window_duration = 10

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "hls",
          options: %{targetWindowDuration: target_window_duration}
        )

      properties = @hls_properties |> Map.put("targetWindowDuration", target_window_duration)

      assert %{"data" => %{"type" => "hls", "properties" => ^properties}} =
               model_response(conn, :created, "ComponentDetailsResponse")

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)
      assert_no_hls_path(room_id)
    end

    test "renders component with ll-hls enabled", %{conn: conn, room_id: room_id} do
      assert Registry.lookup(Jellyfish.RequestHandlerRegistry, room_id) |> Enum.empty?()

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls", options: %{lowLatency: true})

      properties = @hls_properties |> Map.put("lowLatency", true)

      assert %{"data" => %{"id" => id, "type" => "hls", "properties" => ^properties}} =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "hls")

      [{request_handler, _value}] = Registry.lookup(Jellyfish.RequestHandlerRegistry, room_id)
      assert Process.alive?(request_handler)
      Process.monitor(request_handler)

      {:ok, %{engine_pid: engine_pid}} = RoomService.get_room(room_id)
      assert Process.alive?(request_handler)
      Process.monitor(engine_pid)

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)
      assert_no_hls_path(room_id)

      # Engine can terminate up to around 5 seconds
      # Hls endpoint tries to process all streams to the end before termination
      # It has 5 seconds for it
      assert_receive {:DOWN, _ref, :process, ^engine_pid, :normal}, 10_000
      assert_receive {:DOWN, _ref, :process, ^request_handler, :normal}

      assert Registry.lookup(Jellyfish.RequestHandlerRegistry, room_id) |> Enum.empty?()
    end

    test "renders errors when video codec is different than h264 - vp8", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "vp8")

      assert %{"id" => room_id} =
               model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Incompatible video codec enforced in room #{room_id}"
    end

    test "renders errors when video codec is different than h264 - nil", %{conn: conn} do
      conn = post(conn, ~p"/room")

      assert %{"id" => room_id} =
               model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Incompatible video codec enforced in room #{room_id}"
    end
  end

  defp create_h264_room(%{conn: conn}) do
    conn = post(conn, ~p"/room", videoCodec: "h264")

    assert %{"id" => room_id} =
             model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

    %{room_id: room_id}
  end

  defp assert_hls_path(room_id, persistent: persistent) do
    hls_path = HLS.output_dir(room_id, persistent: persistent)
    assert {:ok, ^hls_path} = HLS.EtsHelper.get_hls_folder_path(room_id)
  end

  defp assert_no_hls_path(room_id) do
    assert {:error, :room_not_found} = HLS.EtsHelper.get_hls_folder_path(room_id)
  end

  defp add_files_for_s3_upload(room_id) do
    {:ok, hls_dir} = HLS.EtsHelper.get_hls_folder_path(room_id)
    assert :ok = wait_for_folder(hls_dir, 1000)

    for filename <- @files, do: :ok = hls_dir |> Path.join(filename) |> File.write(@body)
  end

  defp wait_for_folder(_hls_dir, milliseconds) when milliseconds < 0, do: {:error, :timeout}

  defp wait_for_folder(hls_dir, milliseconds) do
    if File.exists?(hls_dir) do
      :ok
    else
      Process.sleep(100)
      wait_for_folder(hls_dir, milliseconds - 100)
    end
  end
end
