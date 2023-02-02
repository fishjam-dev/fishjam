defmodule JellyfishWeb.RoomControllerTest do
  use JellyfishWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all rooms", %{conn: conn} do
      conn = get(conn, Routes.room_path(conn, :index))
      assert json_response(conn, :ok)["data"] == []
    end
  end

  describe "create room" do
    test "renders room when data is valid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), maxPeers: 10)
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"maxPeers" => 10},
               "components" => [],
               "peers" => []
             } = json_response(conn, :ok)["data"]
    end

    test "renders room when max_peers isn't present", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create))
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"maxPeers" => nil},
               "components" => [],
               "peers" => []
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), maxPeers: "abc123")

      assert json_response(conn, :unprocessable_entity)["errors"] ==
               "maxPeers must be a number"
    end
  end

  describe "delete room" do
    setup [:create_room]

    test "deletes chosen room", %{conn: conn, room_id: room_id} do
      conn = delete(conn, Routes.room_path(conn, :delete, room_id))
      assert response(conn, :no_content)

      conn = get(conn, Routes.room_path(conn, :show, room_id))
      assert json_response(conn, :not_found) == %{"errors" => "Room #{room_id} does not exist"}
    end

    test "returns 404 if room doesn't exists", %{conn: conn} do
      conn = delete(conn, Routes.room_path(conn, :delete, "abc303"))
      assert response(conn, :not_found)
    end
  end

  defp create_room(state) do
    conn = post(state.conn, Routes.room_path(state.conn, :create))
    assert %{"id" => id} = json_response(conn, :created)["data"]

    %{room_id: id}
  end
end
