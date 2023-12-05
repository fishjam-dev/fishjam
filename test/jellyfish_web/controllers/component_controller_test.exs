defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase

  import OpenApiSpex.TestAssertions
  import Mox

  alias Jellyfish.Component.HLS

  @schema JellyfishWeb.ApiSpec.spec()
  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"
  @file_component_directory "file_component_sources"
  @file_component_source "video.h264"
  @files ["manifest.m3u8", "header.mp4", "segment_1.m3u8", "segment_2.m3u8"]
  @body <<1, 2, 3, 4>>

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)
    conn = put_req_header(conn, "accept", "application/json")

    media_sources_directory =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@file_component_directory)
      |> Path.expand()

    File.mkdir_p!(media_sources_directory)

    media_sources_directory
    |> Path.join(@file_component_source)
    |> File.touch!()

    conn = post(conn, ~p"/room")
    assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

    on_exit(fn ->
      conn = delete(conn, ~p"/room/#{id}")
      assert response(conn, :no_content)
    end)

    {:ok, %{conn: conn, room_id: id}}
  end

  describe "create component" do
    test "renders errors when component type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "invalid_type")

      assert json_response(conn, :bad_request)["errors"] == "Invalid component type"
    end

    test "renders errors when room doesn't exists", %{conn: conn} do
      room_id = "abc"
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end
  end

  describe "create hls component" do
    @describetag :gpu

    test "renders component when data is valid, allows max 1 hls per room", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "h264")
      assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "hls",
                   "properties" => %{
                     "playable" => false,
                     "lowLatency" => false,
                     "persistent" => false,
                     "targetWindowDuration" => nil,
                     "subscribeMode" => "auto"
                   }
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      assert_hls_path(room_id, persistent: false)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "hls"}
               ]
             } = json_response(conn, :ok)["data"]

      # Try to add another hls component
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert json_response(conn, :bad_request)["errors"] ==
               "Reached components limit in room #{room_id}"

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)
      assert_no_hls_path(room_id)
    end

    test "renders component with peristent enabled", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "h264")
      assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls", options: %{persistent: true})

      assert response =
               %{
                 "data" => %{
                   "type" => "hls",
                   "properties" => %{
                     "playable" => false,
                     "lowLatency" => false,
                     "persistent" => true,
                     "targetWindowDuration" => nil,
                     "subscribeMode" => "auto"
                   }
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)
      assert_hls_path(room_id, persistent: true)

      # It is persistent stream so we have to remove it manually
      assert {:ok, _removed_files} = room_id |> HLS.Recording.directory() |> File.rm_rf()
    end

    setup :set_mox_from_context
    setup :verify_on_exit!

    test "renders component with s3 credentials", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "h264")
      assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

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

      assert response =
               %{
                 "data" => %{
                   "type" => "hls",
                   "properties" => %{
                     "playable" => false,
                     "lowLatency" => false,
                     "persistent" => false,
                     "targetWindowDuration" => nil,
                     "subscribeMode" => "auto"
                   }
                 }
               } =
               json_response(conn, :created)

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

      assert_response_schema(response, "ComponentDetailsResponse", @schema)
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

    test "renders component with targetWindowDuration set", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "h264")
      assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "hls",
          options: %{targetWindowDuration: 10}
        )

      assert response =
               %{
                 "data" => %{
                   "type" => "hls",
                   "properties" => %{
                     "playable" => false,
                     "lowLatency" => false,
                     "persistent" => false,
                     "targetWindowDuration" => 10,
                     "subscribeMode" => "auto"
                   }
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)
      assert_no_hls_path(room_id)
    end

    test "renders component with ll-hls enabled", %{conn: conn} do
      conn = post(conn, ~p"/room", videoCodec: "h264")
      assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

      assert Registry.lookup(Jellyfish.RequestHandlerRegistry, room_id) |> Enum.empty?()

      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls", options: %{lowLatency: true})

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "hls",
                   "properties" => %{"playable" => false, "lowLatency" => true}
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "hls"}
               ]
             } = json_response(conn, :ok)["data"]

      [{request_handler, _value}] = Registry.lookup(Jellyfish.RequestHandlerRegistry, room_id)
      assert Process.alive?(request_handler)
      Process.monitor(request_handler)

      {:ok, %{engine_pid: engine_pid}} = Jellyfish.RoomService.get_room(room_id)
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

    test "renders errors when request body structure is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", invalid_parameter: "hls")

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end

    test "renders errors when video codec is different than h264", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert json_response(conn, :bad_request)["errors"] ==
               "Incompatible video codec enforced in room #{room_id}"
    end
  end

  describe "create rtsp component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "rtsp",
          options: %{sourceUri: @source_uri}
        )

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "rtsp",
                   "properties" => %{}
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "rtsp"}
               ]
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when component requires options not present in request", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "rtsp")

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "Create File Component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @file_component_source}
        )

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "file",
                   "properties" => %{}
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "file"}
               ]
             } = json_response(conn, :ok)["data"]
    end

    test "renders error when component requires options not present in request", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "file")

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end

    test "renders error when filePath is invalid", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: "some/fake/path.h264"}
        )

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "delete component" do
    setup [:create_rtsp_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert response(conn, :no_content)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => []
             } = json_response(conn, :ok)["data"]
    end

    test "deletes not existing component", %{conn: conn, room_id: room_id} do
      component_id = "test123"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert json_response(conn, :not_found)["errors"] ==
               "Component #{component_id} does not exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, component_id: component_id} do
      room_id = "abc"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end
  end

  defp create_rtsp_component(state) do
    conn =
      post(state.conn, ~p"/room/#{state.room_id}/component",
        type: "rtsp",
        options: %{sourceUri: @source_uri}
      )

    assert %{"id" => id} = json_response(conn, :created)["data"]

    %{component_id: id}
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
