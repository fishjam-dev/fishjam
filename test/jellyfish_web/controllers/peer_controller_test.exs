defmodule FishjamWeb.PeerControllerTest do
  use FishjamWeb.ConnCase

  import OpenApiSpex.TestAssertions

  @schema FishjamWeb.ApiSpec.spec()
  @peer_type "webrtc"

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:fishjam, :server_api_token)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> server_api_token)
      |> put_req_header("accept", "application/json")

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

    on_exit(fn ->
      conn = delete(conn, ~p"/room/#{id}")
      assert response(conn, :no_content)
    end)

    peer_ws_url = Fishjam.peer_websocket_address()

    {:ok, %{conn: conn, room_id: id, peer_ws_url: peer_ws_url}}
  end

  describe "create peer" do
    test "renders peer when data is valid", %{
      conn: conn,
      room_id: room_id,
      peer_ws_url: peer_ws_url
    } do
      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)
      response = json_response(conn, :created)
      assert_response_schema(response, "PeerDetailsResponse", @schema)

      assert %{
               "peer" => %{"id" => peer_id, "type" => @peer_type},
               "token" => token,
               "peer_websocket_url" => ^peer_ws_url
             } = response["data"]

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
                 FishjamWeb.Endpoint,
                 Application.fetch_env!(:fishjam, FishjamWeb.Endpoint)[:secret_key_base],
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
               "Reached webrtc peers limit in room #{room_id}"
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

    test "renders errors when peer isn't allowed globally", %{conn: conn, room_id: room_id} do
      Application.put_env(:fishjam, :webrtc_config, webrtc_used?: false)

      on_exit(fn ->
        Application.put_env(:fishjam, :webrtc_config, webrtc_used?: true)
      end)

      conn = post(conn, ~p"/room/#{room_id}/peer", type: @peer_type)

      assert json_response(conn, :bad_request)["errors"] ==
               "Peers of type webrtc are disabled on this Fishjam"
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
