defmodule JellyfishWeb.Component.RecordingComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @s3_credentials %{
    accessKeyId: "access_key_id",
    secretAccessKey: "secret_access_key",
    region: "region",
    bucket: "bucket"
  }

  @path_prefix "path_prefix"

  describe "create recording component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{credentials: Enum.into(@s3_credentials, %{}), pathPrefix: @path_prefix}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => %{"pathPrefix" => @path_prefix}
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "recording")
    end

    test "renders component when credentials are in passed in config", %{
      conn: conn,
      room_id: room_id
    } do
      Application.put_env(:jellyfish, :s3_credentials, @s3_credentials)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => %{"pathPrefix" => @path_prefix}
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "recording")
    end

    test "renders errors when required options are missing", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "S3 credentials has to be passed either by request or at application startup as envs"
    end
  end
end
