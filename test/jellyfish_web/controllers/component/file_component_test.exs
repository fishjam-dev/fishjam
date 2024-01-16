defmodule JellyfishWeb.Component.FileComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @file_component_directory "file_component_sources"
  @video_source "video.h264"
  @audio_source "audio.ogg"

  setup_all _tags do
    media_sources_directory =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@file_component_directory)
      |> Path.expand()

    File.mkdir_p!(media_sources_directory)

    media_sources_directory
    |> Path.join(@video_source)
    |> File.touch!()

    media_sources_directory
    |> Path.join(@audio_source)
    |> File.touch!()

    on_exit(fn -> :file.del_dir_r(media_sources_directory) end)

    {:ok, %{media_sources_directory: media_sources_directory}}
  end

  describe "Create File Component" do
    test "renders component with video as source", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => @video_source
                 }
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")
    end

    test "renders component with audio as source", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @audio_source}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => @audio_source
                 }
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")
    end

    test "file in subdirectory", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      subdir_name = "subdirectory"
      video_relative_path = Path.join(subdir_name, @video_source)
      [media_sources_directory, subdir_name] |> Path.join() |> File.mkdir_p!()
      media_sources_directory |> Path.join(video_relative_path) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: video_relative_path}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => ^video_relative_path
                 }
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")
    end

    test "renders error when required options are missing", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "file")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Required field \"filePath\" missing"
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

      assert model_response(conn, :not_found, "Error")["errors"] ==
               "File not found"
    end

    test "renders error when file path is outside of media files directory", %{
      conn: conn,
      room_id: room_id
    } do
      filepath = "../restricted_audio.opus"

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Invalid file path"
    end

    test "renders error when file has no extension", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      filepath = "h264"
      media_sources_directory |> Path.join(filepath) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Unsupported file type"
    end

    test "renders error when file has invalid extension", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      filepath = "sounds.aac"
      media_sources_directory |> Path.join(filepath) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Unsupported file type"
    end
  end
end
