defmodule JellyfishWeb.RoomControllerTest do
  use JellyfishWeb.ConnCase

  import OpenApiSpex.TestAssertions

  @schema JellyfishWeb.ApiSpec.spec()

  setup %{conn: conn} do
    on_exit(fn -> delete_all_rooms(conn) end)

    []
  end

  describe "index" do
    test "lists all rooms", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), maxPeers: 10)
      conn = get(conn, Routes.room_path(conn, :index))
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomsListingResponse", @schema)

      assert length(response["data"]) == 1
    end
  end

  describe "create room" do
    test "renders room when data is valid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), maxPeers: 10)
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomDetailsResponse", @schema)

      assert %{
               "id" => ^id,
               "config" => %{"maxPeers" => 10},
               "components" => [],
               "peers" => []
             } = response["data"]
    end

    test "renders room when max_peers isn't present", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create))
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, id))
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomDetailsResponse", @schema)

      assert %{
               "id" => ^id,
               "config" => %{},
               "components" => [],
               "peers" => []
             } = response["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.room_path(conn, :create), maxPeers: "abc123")

      assert json_response(conn, :bad_request)["errors"] ==
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

  defp delete_all_rooms(conn) do
    conn = get(conn, Routes.room_path(conn, :index))
    assert rooms = json_response(conn, :ok)["data"]

    Enum.reduce(rooms, conn, fn room, conn ->
      conn = delete(conn, Routes.room_path(conn, :delete, room["id"]))
      assert response(conn, :no_content)
      conn
    end)
  end
end
