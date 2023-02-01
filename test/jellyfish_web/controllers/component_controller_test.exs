defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase

  @component_type "hls"

  setup %{conn: conn} do
    room_conn = post(conn, Routes.room_path(conn, :create))
    assert %{"id" => id} = json_response(room_conn, :created)["data"]

    on_exit(fn ->
      room_conn = delete(conn, Routes.room_path(conn, :delete, id))
      assert response(room_conn, :no_content)
    end)

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create component" do
    test "renders component when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.component_path(conn, :create, room_id), type: @component_type)
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => @component_type}
               ]
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.component_path(conn, :create, room_id), type: "test_type")

      assert json_response(conn, :bad_request)["errors"] == "Invalid component type"
    end

    test "renders errors when request body structure is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), component_type: @component_type)
      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "delete component" do
    setup [:create_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, Routes.component_path(conn, :delete, room_id, component_id))
      assert response(conn, :no_content)

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "components" => []
             } = json_response(conn, :ok)["data"]
    end

    test "deletes not existing component", %{conn: conn, room_id: room_id} do
      component_id = "test123"
      conn = delete(conn, Routes.component_path(conn, :delete, room_id, component_id))

      assert json_response(conn, :not_found)["errors"] ==
               "Component #{component_id} does not exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, component_id: component_id} do
      room_id = "abc"
      conn = delete(conn, Routes.component_path(conn, :delete, room_id, component_id))
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end
  end

  defp create_component(state) do
    conn =
      post(state.conn, Routes.component_path(state.conn, :create, state.room_id),
        type: @component_type
      )

    assert %{"id" => id} = json_response(conn, :created)["data"]

    %{component_id: id}
  end
end
