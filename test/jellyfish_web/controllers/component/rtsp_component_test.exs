defmodule JellyfishWeb.Component.RTSPComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

  @rtsp_default_properties %{
    sourceUri: @source_uri,
    rtpPort: 20_000,
    reconnectDelay: 15_000,
    keepAliveInterval: 15_000,
    pierceNat: true
  } |> map_keys_to_string()

  @rtsp_custom_options %{
    sourceUri: @source_uri,
    rtpPort: 2137,
    reconnectDelay: 5_000,
    keepAliveInterval: 5_000,
    pierceNat: false
  }
  @rtsp_custom_properties @rtsp_custom_options |> map_keys_to_string()

  describe "create rtsp component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "rtsp",
          options: %{sourceUri: @source_uri}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "rtsp",
                 "properties" => @rtsp_default_properties
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "rtsp")
    end

    test "renders component with custom options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "rtsp",
          options: @rtsp_custom_options
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "rtsp",
                 "properties" => @rtsp_custom_properties
               }
             } =
               model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "rtsp")
    end

    test "renders errors when required options are missing", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "rtsp")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Required field \"sourceUri\" missing"
    end
  end
end
