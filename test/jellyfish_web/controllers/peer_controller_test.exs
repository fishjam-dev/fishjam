defmodule JellyfishWeb.PeerControllerTest do
  use JellyfishWeb.ConnCase

  import OpenApiSpex.TestAssertions

  @schema JellyfishWeb.ApiSpec.spec()
  @peer_type "webrtc"

  setup %{conn: conn} do
    token = Application.fetch_env!(:jellyfish, :token)
    conn = put_req_header(conn, "authorization", "Bearer " <> token)

    room_conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => id} = json_response(room_conn, :created)["data"]

    on_exit(fn ->
      room_conn = delete(conn, ~p"/room/#{id}")
      assert response(room_conn, :no_content)
    end)

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create peer" do
    test "renders peer when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)
      response = json_response(conn, :created)
      assert_response_schema(response, "PeerDetailsResponse", @schema)

      assert %{"peer" => %{"id" => peer_id, "type" => @peer_type}, "token" => token} =
               response["data"]

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "peers" => [
                 %{
                   "id" => ^peer_id,
                   "type" => @peer_type,
                   "status" => "disconnected"
                 }
               ]
             } = json_response(conn, :ok)["data"]

      assert {:ok, %{peer_id: ^peer_id, room_id: ^room_id}} =
               Phoenix.Token.verify(
                 JellyfishWeb.Endpoint,
                 Application.get_env(:jellyfish, :auth_salt),
                 token
               )
    end

    test "renders errors when peer_type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/peer", type: "invalid_type")
      assert json_response(conn, :bad_request)["errors"] == "Invalid peer type"
    end

    test "renders errors when reached peers limit", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)
      assert %{"peer" => _peer, "token" => _token} = json_response(conn, :created)["data"]

      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)

      assert json_response(conn, :service_unavailable)["errors"] ==
               "Reached peer limit in room #{room_id}"
    end

    test "renders errors when room doesn't exist", %{conn: conn} do
      room_id = "invalid_room"
      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end

    test "renders errors when request body structure is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/peer", invalid_param: @peer_type)
      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "delete peer" do
    setup [:create_peer]

    test "deletes chosen peer", %{conn: conn, room_id: room_id, peer_id: peer_id} do
      conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")
      assert response(conn, :no_content)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "peers" => []
             } = json_response(conn, :ok)["data"]
    end

    test "deletes not existing peer", %{conn: conn, room_id: room_id} do
      peer_id = "invalid_peer"
      conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")

      assert json_response(conn, :not_found)["errors"] ==
               "Peer #{peer_id} does not exist"
    end

    test "deletes peer from not exisiting room", %{conn: conn, peer_id: peer_id} do
      room_id = "invalid_room"
      conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end

    defp create_peer(state) do
      conn = post(state.conn, ~p"/room/#{state.room_id}/peer", type: @peer_type)

      assert %{"peer" => %{"id" => peer_id}, "token" => token} =
               json_response(conn, :created)["data"]

      %{peer_id: peer_id, token: token}
    end
  end
end
