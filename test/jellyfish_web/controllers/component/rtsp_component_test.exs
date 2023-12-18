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

      assert response =
               %{
                 "data" => %{
                   "id" => id,
                   "type" => "rtsp",
                   "properties" => %{}
                 }
               } =
               json_response(conn, :created)

      assert_response_schema(response, "ComponentDetailsResponse")

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

end
