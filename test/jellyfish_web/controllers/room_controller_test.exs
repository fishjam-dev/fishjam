defmodule JellyfishWeb.RoomControllerTest do
  use JellyfishWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all rooms", %{conn: conn} do
      conn = get(conn, Routes.room_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create room" do
    test "renders room when data is valid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), max_peers: 10)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"max_peers" => 10},
               "producers" => [],
               "consumers" => []
             } = json_response(conn, 200)["data"]
    end

    test "renders room when max_peers isn't present", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create))
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"max_peers" => nil},
               "producers" => [],
               "consumers" => []
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), max_peers: "abc123")
      assert json_response(conn, 422)["errors"] == "max_peers should be number if passed"
    end
  end

  describe "delete room" do
    setup [:create_room]

    test "deletes chosen room", %{conn: conn, room_id: room_id} do
      conn = delete(conn, Routes.room_path(conn, :delete, room_id))
      assert response(conn, 204)

      conn = get(conn, Routes.room_path(conn, :show, room_id))
      assert json_response(conn, 404) == %{"errors" => "Room not found"}
    end

    test "returns 404 if room doesn't exists", %{conn: conn} do
      conn = delete(conn, Routes.room_path(conn, :delete, "abc303"))
      assert response(conn, 404)
    end
  end

  defp create_room(state) do
    conn = post(state.conn, Routes.room_path(state.conn, :create))
    assert %{"id" => id} = json_response(conn, 201)["data"]

    %{room_id: id}
  end
end
