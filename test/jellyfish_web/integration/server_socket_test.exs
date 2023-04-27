defmodule JellyfishWeb.Integration.ServerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint
  alias Jellyfish.Server.ControlMessage

  alias Jellyfish.Server.ClientMessage.TokenMessage

  alias Jellyfish.Server.ServerNotification.{
    Authenticated,
    PeerNotification,
    RoomNotification
  }

  alias JellyfishWeb.{PeerSocket, ServerSocket, WS}

  @port 5907
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"
  @auth_response ControlMessage.encode(%ControlMessage{content: {:roomCrashed, %Authenticated{}}})

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

    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "correct token" do
    create_and_authenticate()
  end

  test "closes on receiving a message from a client" do
    ws = create_and_authenticate()

    :ok =
      WS.send_binary_frame(
        ws,
        ControlMessage.encode(%ControlMessage{content: {:authenticated, %Authenticated{}}})
      )

    assert_receive {:disconnected, {:remote, 1003, "operation not allowed"}}, 1000
  end

  test "sends a message when room crashes", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    create_and_authenticate()

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]
    {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

    Process.exit(room_pid, :kill)

    receive do
      msg when is_binary(msg) ->
        assert %ControlMessage{
                 content: {:roomCrashed, %RoomNotification{roomId: ^room_id}}
               } = ControlMessage.decode(msg)
    end
  end

  test "sends a message when peer connects", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    create_and_authenticate()

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => peer_token, "peer" => %{"id" => peer_id}} =
             json_response(conn, :created)["data"]

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket")

    auth_request = peer_auth_request(peer_token)

    :ok = WS.send_frame(peer_ws, auth_request)

    assert_receive %{"data" => %{"type" => "authenticated"}, "type" => "controlMessage"}

    conn = delete(conn, ~p"/room/#{room_id}/")
    response(conn, :no_content)

    receive do
      msg when is_binary(msg) ->
        case ControlMessage.decode(msg) do
          %ControlMessage{
            content: {:peerDisconnected, %PeerNotification{peerId: ^peer_id, roomId: ^room_id}}
          } ->
            assert true

          _other ->
            nil
        end
    end
  end

  def create_and_authenticate(token \\ Application.fetch_env!(:jellyfish, :server_api_token)) do
    auth_request = auth_request(token)

    {:ok, ws} = WS.start_link(@path)
    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive @auth_response, 1000

    ws
  end

  defp auth_request(token) do
    ControlMessage.encode(%ControlMessage{content: {:authRequest, %TokenMessage{token: token}}})
  end

  defp peer_auth_request(token) do
    %{
      "type" => "controlMessage",
      "data" => %{"type" => "authRequest", "token" => token}
    }
  end
end
