defmodule JellyfishWeb.EndpointControllerTest do
  use JellyfishWeb.ConnCase

  alias Jellyfish.Endpoints.Endpoint

  setup %{conn: conn} do
    room_conn = post(conn, Routes.room_path(conn, :create))
    assert %{"id" => id} = json_response(room_conn, 201)["data"]
    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create endpoint" do
    test "renders endpoint when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.endpoint_path(conn, :create, room_id), endpoint_type: "hls")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "endpoints" => [%{"id" => ^id, "type" => "hls"}]
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.endpoint_path(conn, :create, room_id), endpoint_type: "test_type")
      assert json_response(conn, 400)["errors"] == "Not proper endpoint type"
    end
  end

  describe "delete endpoint" do
    setup [:create_endpoint]

    test "deletes chosen endpoint", %{conn: conn, room_id: room_id, endpoint_id: endpoint_id} do
      conn = delete(conn, Routes.endpoint_path(conn, :delete, room_id, endpoint_id))
      assert response(conn, 204)

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "endpoints" => []
             } = json_response(conn, 200)["data"]
    end

    test "deletes not existing endpoint", %{conn: conn, room_id: room_id} do
      endpoint_id = "test123"
      conn = delete(conn, Routes.endpoint_path(conn, :delete, room_id, endpoint_id))
      assert json_response(conn, 404)["errors"] == "Endpoint with id #{endpoint_id} doesn't exist"
    end

    test "deletes endpoint from not exisiting room", %{conn: conn, endpoint_id: endpoint_id} do
      conn = delete(conn, Routes.endpoint_path(conn, :delete, "abc", endpoint_id))
      assert json_response(conn, 400)["errors"] == "Room not found"
    end
  end

  defp create_endpoint(state) do
    conn =
      post(state.conn, Routes.endpoint_path(state.conn, :create, state.room_id),
        endpoint_type: "hls"
      )

    assert %{"id" => id} = json_response(conn, 201)["data"]

    %{endpoint_id: id}
  end
end
