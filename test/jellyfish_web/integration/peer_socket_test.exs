defmodule JellyfishWeb.Integration.PeerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint
  alias Jellyfish.RoomService
  alias JellyfishWeb.{PeerSocket, WS}

  @port 5908
  @path "ws://127.0.0.1:#{@port}/socket/peer/websocket"

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

    room_conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(room_conn, :created)["data"]
    {:ok, _room_pid} = RoomService.find_room(room_id)

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => token} = json_response(conn, :created)["data"]

    on_exit(fn ->
      RoomService.delete_room(room_id)
    end)

    {:ok,
     %{
       room_id: room_id,
       authenticated?: false,
       token: token
     }}
  end

  test "invalid token", %{token: token} do
    {:ok, ws} = WS.start_link(@path)

    auth_request = auth_request("invalid" <> token)

    :ok = WS.send_frame(ws, auth_request)

    assert_receive {:disconnected, {:remote, 1000, ":invalid_token"}}, 1000
  end

  test "correct token", %{token: token} do
    {:ok, ws} = WS.start_link(@path)

    auth_request = auth_request(token)

    :ok = WS.send_frame(ws, auth_request)

    assert_receive %{
                     "type" => "controlMessage",
                     "data" => %{
                       "type" => "authenticated"
                     }
                   },
                   1000
  end

  test "valid token but peer doesn't exist", %{room_id: room_id} do
    {:ok, ws} = WS.start_link(@path)

    unadded_peer_token = JellyfishWeb.PeerToken.generate(%{peer_id: "peer_id", room_id: room_id})
    auth_request = auth_request(unadded_peer_token)

    :ok = WS.send_frame(ws, auth_request)

    assert_receive {:disconnected, {:remote, 1000, ":peer_not_found"}}, 1000
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

  test "message from unauthenticated peer" do
    {:ok, ws} = WS.start_link(@path)

    msg = Jason.encode!(%{"type" => "mediaEvent", "data" => "some data"})

    :ok = WS.send_frame(ws, msg)

    assert_receive {:disconnected, {:remote, 1000, "unauthenticated"}}, 1000
  end
end
