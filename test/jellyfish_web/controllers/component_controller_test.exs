defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase

  setup %{conn: conn} do
    room_conn = post(conn, Routes.room_path(conn, :create))
    assert %{"id" => id} = json_response(room_conn, 201)["data"]
    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create component" do
    test "renders component when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.component_path(conn, :create, room_id), component_type: "hls")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "components" => [%{"id" => ^id, "type" => "hls"}]
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, Routes.component_path(conn, :create, room_id), component_type: "test_type")

      assert json_response(conn, 400)["errors"] == "Not proper component type"
    end
  end

  describe "delete component" do
    setup [:create_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, Routes.component_path(conn, :delete, room_id, component_id))
      assert response(conn, 204)

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "components" => []
             } = json_response(conn, 200)["data"]
    end

    test "deletes not existing component", %{conn: conn, room_id: room_id} do
      component_id = "test123"
      conn = delete(conn, Routes.component_path(conn, :delete, room_id, component_id))

      assert json_response(conn, 404)["errors"] ==
               "Component with id #{component_id} doesn't exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, component_id: component_id} do
      conn = delete(conn, Routes.component_path(conn, :delete, "abc", component_id))
      assert json_response(conn, 400)["errors"] == "Room not found"
    end
  end

  defp create_component(state) do
    conn =
      post(state.conn, Routes.component_path(state.conn, :create, state.room_id),
        component_type: "hls"
      )

    assert %{"id" => id} = json_response(conn, 201)["data"]

    %{component_id: id}
  end
end
