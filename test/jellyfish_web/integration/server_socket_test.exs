defmodule JellyfishWeb.Integration.ServerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint
  alias JellyfishWeb.{PeerSocket, ServerSocket, WS}

  @port 5907
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"
  @auth_response %{
    "type" => "controlMessage",
    "data" => %{
      "type" => "authenticated"
    }
  }

  Application.put_env(
    :jellyfish,
    Endpoint,
    https: false,
    http: [port: @port],
    server: true
  )

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :jellyfish

    alias JellyfishWeb.ServerSocket

    socket "/socket/server", ServerSocket,
      websocket: true,
      longpoll: false

    socket "/socket/peer", PeerSocket,
      websocket: true,
      longpoll: false
  end

  setup_all do
    assert {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  test "invalid token" do
    {:ok, ws} = WS.start_link(@path)
    server_api_token = "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "missing token" do
    {:ok, ws} = WS.start_link(@path)

    {_server_api_token, auth_request} =
      Application.fetch_env!(:jellyfish, :server_api_token)
      |> auth_request()
      |> pop_in([:data, :token])

    :ok = WS.send_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid auth request"}}, 1000
  end

  test "correct token" do
    {:ok, ws} = WS.start_link(@path)
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_frame(ws, auth_request)
    assert_receive @auth_response, 1000
  end

  test "closes on receiving a message from a client" do
    {:ok, ws} = WS.start_link(@path)
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_frame(ws, auth_request)

    :ok = WS.send_frame(ws, %{type: "controlMessage", data: "dummy data"})

    assert_receive {:disconnected, {:remote, 1003, "operation not allowed"}}, 1000
  end

  test "sends a message when room crashes", %{conn: conn} do
    {:ok, ws} = WS.start_link(@path)
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_frame(ws, auth_request)

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]
    {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

    Process.exit(room_pid, :kill)

    assert_receive %{
      "data" => %{"roomId" => ^room_id, "type" => "roomCrashed"},
      "type" => "controlMessage"
    }
  end

  test "sends a message when peer connects", %{conn: conn} do
    {:ok, ws} = WS.start_link(@path)
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_frame(ws, auth_request)

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => peer_token, "peer" => %{"id" => peer_id}} =
             json_response(conn, :created)["data"]

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket")

    auth_request = auth_request(peer_token)

    :ok = WS.send_frame(peer_ws, auth_request)

    assert_receive %{
      "data" => %{"id" => ^peer_id, "type" => "peerConnected"},
      "type" => "controlMessage"
    }

    conn = delete(conn, ~p"/room/#{room_id}/")
    response(conn, :no_content)

    assert_receive %{
      "data" => %{"id" => ^peer_id, "type" => "peerDisconnected"},
      "type" => "controlMessage"
    }
  end

  defp auth_request(token) do
    %{
      type: "controlMessage",
      data: %{
        type: "authRequest",
        token: token
      }
    }
  end
end
