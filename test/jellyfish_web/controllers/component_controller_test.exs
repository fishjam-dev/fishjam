defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

  describe "create component" do
    test "renders errors when component type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "invalid_type")

      response = json_response(conn, :bad_request)
      assert response["errors"] == "Invalid component type"
      assert_response_schema(response, "Error")
    end

    test "renders errors when room doesn't exists", %{conn: conn} do
      room_id = "abc"
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      response = json_response(conn, :not_found)
      assert response["errors"] == "Room #{room_id} does not exist"
      assert_response_schema(response, "Error")
    end
  end

  describe "delete component" do
    setup [:create_rtsp_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")
      assert response(conn, :no_content)

      conn = get(conn, ~p"/room/#{room_id}")
      response = json_response(conn, :ok)
      assert %{
               "id" => ^room_id,
               "components" => []
             } = response["data"]
      assert_response_schema(response, "RoomDetailsResponse")
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
end
