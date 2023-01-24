defmodule JellyfishWeb.PeerControllerTest do
  use JellyfishWeb.ConnCase

  setup %{conn: conn} do
    room_conn = post(conn, Routes.room_path(conn, :create), max_peers: 1)
    assert %{"id" => id} = json_response(room_conn, 201)["data"]

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create peer" do
    test "renders peer when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), peer_type: "webrtc")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.room_path(conn, :show, room_id))

      assert %{
               "id" => ^room_id,
               "peers" => [%{"id" => ^id, "type" => "Elixir.Membrane.RTC.Engine.Endpoint.WebRTC"}]
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when peer_type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), peer_type: "abc")
      assert json_response(conn, 400)["errors"] == "Not proper peer_type"
    end

    test "renders errors when reached peers limit", %{conn: conn, room_id: room_id} do
      conn = post(conn, Routes.peer_path(conn, :create, room_id), peer_type: "webrtc")
      assert %{"id" => _id} = json_response(conn, 201)["data"]

      conn = post(conn, Routes.peer_path(conn, :create, room_id), peer_type: "webrtc")

      assert json_response(conn, 503)["errors"] == "Reached peers limit in room"
    end

    test "renders errors when room doesn't exist", %{conn: conn} do
      conn = post(conn, Routes.peer_path(conn, :create, "abc"), peer_type: "webrtc")
      assert json_response(conn, 400)["errors"] == "Room not found"
    end
  end
end
