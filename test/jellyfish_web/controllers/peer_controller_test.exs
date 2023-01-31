defmodule JellyfishWeb.PeerControllerTest do
  use JellyfishWeb.ConnCase

  @peer_type "webrtc"

  setup %{conn: conn} do
    room_conn = post(conn, Routes.room_path(conn, :create), maxPeers: 1)
    assert %{"id" => id} = json_response(room_conn, :created)["data"]

    on_exit(fn ->
        room_conn = delete(conn, Routes.room_path(conn, :delete, id))
        assert response(room_conn, :no_content)
      end)

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create peer" do
    test "renders peer when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), type: @peer_type)
      assert %{"id" => id, "type" => @peer_type} = json_response(conn, :created)["data"]

      conn = get(conn, Routes.room_path(conn, :show, room_id))
      assert %{
               "id" => ^room_id,
               "peers" => [%{"id" => ^id, "type" => @peer_type}]
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when peer_type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), type: "abc")
      assert json_response(conn, :bad_request)["errors"] == "Invalid peer type"
    end

    test "renders errors when reached peers limit", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), type: @peer_type)
      assert %{"id" => _id} = json_response(conn, :created)["data"]

      conn = post(conn, Routes.peer_path(conn, :create, room_id), type: @peer_type)

      assert json_response(conn, :service_unavailable)["errors"] == "Reached peer limit in the room"
    end

    test "renders errors when room doesn't exist", %{conn: conn} do
      conn = post(conn, Routes.peer_path(conn, :create, "abc"), type: @peer_type)
      assert json_response(conn, :not_found)["errors"] == "Room not found"
    end

    test "renders errors when request body structure is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), peer_type: @peer_type)
      assert json_response(conn, :bad_request)["errors"] == "Request body has invalid structure"
    end
  end

  describe "delete peer" do
    setup [:create_peer]

    test "deletes chosen peer", %{conn: conn, room_id: room_id, peer_id: peer_id} do
      conn = delete(conn, Routes.peer_path(conn, :delete, room_id, peer_id))
      assert response(conn, :no_content)

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "peers" => []
             } = json_response(conn, :ok)["data"]
    end

    test "deletes not existing peer", %{conn: conn, room_id: room_id} do
      peer_id = "test123"
      conn = delete(conn, Routes.peer_path(conn, :delete, room_id, peer_id))

      assert json_response(conn, :not_found)["errors"] ==
        "Peer with id #{peer_id} doesn't exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, peer_id: peer_id} do
      conn = delete(conn, Routes.peer_path(conn, :delete, "abc", peer_id))
      assert json_response(conn, :not_found)["errors"] == "Room not found"
    end

    defp create_peer(state) do
      conn =
        post(state.conn, Routes.peer_path(state.conn, :create, state.room_id),
          type: @peer_type
        )

      assert %{"id" => id} = json_response(conn, :created)["data"]

      %{peer_id: id}
    end
  end
end
