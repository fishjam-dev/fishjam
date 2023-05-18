defmodule JellyfishWeb.Integration.PeerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint
  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.{Authenticated, AuthRequest, MediaEvent}
  alias Jellyfish.RoomService
  alias JellyfishWeb.{PeerSocket, WS}

  @port 5908
  @path "ws://127.0.0.1:#{@port}/socket/peer/websocket"
  @auth_response %Authenticated{}

  Application.put_env(
    :jellyfish,
    Endpoint,
    https: false,
    http: [port: @port],
    server: true
  )

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :jellyfish

    alias JellyfishWeb.PeerSocket

    socket "/socket/peer", PeerSocket,
      websocket: true,
      longpoll: false
  end

  setup_all do
    assert {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]
    {:ok, room_pid} = RoomService.find_room(room_id)

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => token, "peer" => peer} = json_response(conn, :created)["data"]

    on_exit(fn ->
      RoomService.delete_room(room_id)
    end)

    {:ok,
     %{
       room_id: room_id,
       room_pid: room_pid,
       peer_id: Map.fetch!(peer, "id"),
       token: token,
       conn: conn
     }}
  end

  test "invalid token", %{token: token} do
    {:ok, ws} = WS.start_link(@path, :peer)
    auth_request = auth_request("invalid" <> token)
    :ok = WS.send_binary_frame(ws, auth_request)

    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "correct token", %{token: token} do
    create_and_authenticate(token)
  end

  test "valid token but peer doesn't exist", %{room_id: room_id} do
    {:ok, ws} = WS.start_link(@path, :peer)

    unadded_peer_token = JellyfishWeb.PeerToken.generate(%{peer_id: "peer_id", room_id: room_id})
    auth_request = auth_request(unadded_peer_token)

    :ok = WS.send_binary_frame(ws, auth_request)

    assert_receive {:disconnected, {:remote, 1000, "peer not found"}}, 1000
  end

  test "valid token but room doesn't exist", %{room_id: room_id, token: token, conn: conn} do
    _conn = delete(conn, ~p"/room/#{room_id}")

    {:ok, ws} = WS.start_link(@path, :peer)
    auth_request = auth_request(token)
    :ok = WS.send_binary_frame(ws, auth_request)

    assert_receive {:disconnected, {:remote, 1000, "room not found"}}, 1000
  end

  test "authRequest when already connected", %{token: token} do
    ws = create_and_authenticate(token)

    auth_request = auth_request(token)
    :ok = WS.send_binary_frame(ws, auth_request)
    refute_receive @auth_response, 1000
    refute_receive {:disconnected, {:remote, 1000, _msg}}
  end

  test "two web sockets", %{token: token} do
    create_and_authenticate(token)

    {:ok, ws2} = WS.start_link(@path, :peer)
    auth_request = auth_request(token)
    :ok = WS.send_binary_frame(ws2, auth_request)

    assert_receive {:disconnected, {:remote, 1000, "peer already connected"}}, 1000
  end

  test "message from unauthenticated peer" do
    {:ok, ws} = WS.start_link(@path, :peer)

    msg =
      PeerMessage.encode(%PeerMessage{
        content: {:media_event, %MediaEvent{data: "some data"}}
      })

    :ok = WS.send_binary_frame(ws, msg)

    assert_receive {:disconnected, {:remote, 1000, "unauthenticated"}}, 1000
  end

  test "invalid message structure", %{token: token} do
    ws = create_and_authenticate(token)

    :ok = WS.send_frame_raw(ws, "just a string")
    :ok = WS.send_frame(ws, %{"type" => 34})
    :ok = WS.send_frame(ws, %{"notatype" => 45})
    refute_receive {:disconnected, {:remote, _code, _reason}}, 1000
  end

  test "media event", %{token: token} do
    ws = create_and_authenticate(token)

    data = Jason.encode!(%{"type" => "custom", "data" => %{"type" => "renegotiateTracks"}})
    msg = PeerMessage.encode(%PeerMessage{content: {:media_event, %MediaEvent{data: data}}})
    :ok = WS.send_binary_frame(ws, msg)

    assert_receive %MediaEvent{data: _data}, 1000
  end

  test "peer removal", %{room_id: room_id, peer_id: peer_id, token: token, conn: conn} do
    create_and_authenticate(token)

    _conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")
    assert_receive {:disconnected, {:remote, 1000, ""}}, 1000
  end

  test "room crash", %{room_pid: room_pid, token: token} do
    create_and_authenticate(token)

    Process.exit(room_pid, :error)

    assert_receive {:disconnected, {:remote, 1000, ""}}, 1000
  end

  test "room close", %{room_id: room_id, token: token, conn: conn} do
    create_and_authenticate(token)
    conn = delete(conn, ~p"/room/#{room_id}/")
    response(conn, :no_content)

    assert_receive {:disconnected, {:remote, 1000, ""}}, 1000
  end

  def create_and_authenticate(token) do
    auth_request = auth_request(token)

    {:ok, ws} = WS.start_link(@path, :peer)
    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive @auth_response, 1000

    ws
  end

  defp auth_request(token) do
    PeerMessage.encode(%PeerMessage{content: {:auth_request, %AuthRequest{token: token}}})
  end
end
