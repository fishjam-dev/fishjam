defmodule JellyfishWeb.Component.RTSPComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

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
                 "properties" => %{}
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
