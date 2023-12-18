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

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "file",
                   "properties" => %{}
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse")

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

end
