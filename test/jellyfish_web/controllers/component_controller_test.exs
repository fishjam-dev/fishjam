defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

  describe "create component" do
    test "renders errors when component type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "invalid_type")

      response = model_response(conn, :bad_request, "Error")
      assert response["errors"] == "Invalid component type"
    end

    test "renders errors when room doesn't exists", %{conn: conn} do
      room_id = "abc"
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      response = model_response(conn, :not_found, "Error")
      assert response["errors"] == "Room #{room_id} does not exist"
    end
  end

  describe "delete component" do
    setup [:create_h264_room]
    setup [:create_rtsp_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")
      assert response(conn, :no_content)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => []
             } = model_response(conn, :ok, "RoomDetailsResponse")["data"]
    end

    test "deletes not existing component", %{conn: conn, room_id: room_id} do
      component_id = "test123"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert model_response(conn, :not_found, "Error")["errors"] ==
               "Component #{component_id} does not exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, component_id: component_id} do
      room_id = "abc"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert model_response(conn, :not_found, "Error")["errors"] ==
               "Room #{room_id} does not exist"
    end
  end

  defp create_rtsp_component(state) do
    conn =
      post(state.conn, ~p"/room/#{state.room_id}/component",
        type: "rtsp",
        options: %{sourceUri: @source_uri}
      )

    assert %{"id" => id} = model_response(conn, :created, "ComponentDetailsResponse")["data"]

    %{component_id: id}
  end
end
