defmodule JellyfishWeb.Component.FileComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @file_component_directory "file_component_sources"
  @file_component_source "video.h264"

  setup _tags do
    media_sources_directory =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@file_component_directory)
      |> Path.expand()

    File.mkdir_p!(media_sources_directory)

    media_sources_directory
    |> Path.join(@file_component_source)
    |> File.touch!()

    {:ok, %{}}
  end

  describe "Create File Component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @file_component_source}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{}
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
               "Invalid request body structure"
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
  end
end
