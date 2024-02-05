defmodule JellyfishWeb.Integration.PeerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint
  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.{Authenticated, MediaEvent}
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
    RoomService.list_rooms()
    |> Enum.map(&RoomService.delete_room(&1.id))

    assert {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]
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
    WS.send_auth_request(ws, "invalid" <> token)

    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "correct token", %{token: token} do
    create_and_authenticate(token)
  end

  test "valid token but peer doesn't exist", %{room_id: room_id} do
    {:ok, ws} = WS.start_link(@path, :peer)

    unadded_peer_token = JellyfishWeb.PeerToken.generate(%{peer_id: "peer_id", room_id: room_id})
    WS.send_auth_request(ws, unadded_peer_token)

    assert_receive {:disconnected, {:remote, 1000, "peer not found"}}, 1000
  end

  test "valid token but room doesn't exist", %{room_id: room_id, token: token, conn: conn} do
    _conn = delete(conn, ~p"/room/#{room_id}")

    {:ok, ws} = WS.start_link(@path, :peer)
    WS.send_auth_request(ws, token)

    assert_receive {:disconnected, {:remote, 1000, "room not found"}}, 1000
  end

  test "authRequest when already connected", %{token: token} do
    ws = create_and_authenticate(token)

    WS.send_auth_request(ws, token)
    refute_receive @auth_response, 1000
    refute_receive {:disconnected, {:remote, 1000, _msg}}
  end

  test "two web sockets", %{token: token} do
    create_and_authenticate(token)

    {:ok, ws2} = WS.start_link(@path, :peer)
    WS.send_auth_request(ws2, token)

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

    data = Jason.encode!(%{"type" => "connect", "data" => %{"metadata" => nil}})
    msg = PeerMessage.encode(%PeerMessage{content: {:media_event, %MediaEvent{data: data}}})
    :ok = WS.send_binary_frame(ws, msg)

    assert_receive %MediaEvent{data: data}, 1000
    assert %{"type" => "connected"} = Jason.decode!(data)
  end

  test "peer removal", %{room_id: room_id, peer_id: peer_id, token: token, conn: conn} do
    create_and_authenticate(token)

    _conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")
    assert_receive {:disconnected, {:remote, 1000, "Peer removed"}}, 1000
  end

  test "room crash", %{room_pid: room_pid, token: token} do
    ws = create_and_authenticate(token)
    Process.unlink(ws)
    ref = Process.monitor(ws)

    Process.exit(room_pid, :error)

    assert_receive {:disconnected, {:remote, 1011, "Internal server error"}}, 1000
    assert_receive {:DOWN, ^ref, :process, ^ws, {:remote, 1011, "Internal server error"}}
  end

  test "room close", %{room_id: room_id, token: token, conn: conn} do
    create_and_authenticate(token)
    conn = delete(conn, ~p"/room/#{room_id}/")
    response(conn, :no_content)

    assert_receive {:disconnected, {:remote, 1000, "Room stopped"}}, 1000
  end

  test "proper calculated peer metrics", %{room_id: room_id, token: token, conn: conn} do
    assert %{} = get_peers_room_metrics()
    create_and_authenticate(token)

    peers_in_room_key = "jellyfish_room_peers{room_id=\"#{room_id}\"}"
    peers_in_room_time_key = "jellyfish_room_peer_time_total_seconds{room_id=\"#{room_id}\"}"

    metrics_after_one_tick = %{
      peers_in_room_key => "1",
      peers_in_room_time_key => "500",
      "jellyfish_rooms" => "1"
    }

    Process.sleep(600)

    assert ^metrics_after_one_tick =
             Map.intersect(metrics_after_one_tick, get_peers_room_metrics())

    conn = delete(conn, ~p"/room/#{room_id}/")
    response(conn, :no_content)

    Process.sleep(600)

    metrics_after_removal = %{
      peers_in_room_key => "0",
      peers_in_room_time_key => "500",
      "jellyfish_rooms" => "0"
    }

    assert ^metrics_after_removal = Map.intersect(metrics_after_removal, get_peers_room_metrics())
  end

  def create_and_authenticate(token) do
    {:ok, ws} = WS.start_link(@path, :peer)
    WS.send_auth_request(ws, token)
    assert_receive @auth_response, 1000

    ws
  end

  defp get_peers_room_metrics() do
    "http://localhost:9568/metrics"
    |> HTTPoison.get!()
    |> Map.get(:body)
    |> String.split("\n")
    |> Enum.reject(&(String.starts_with?(&1, "# HELP") or String.starts_with?(&1, "# TYPE")))
    |> Enum.reduce(%{}, fn elem, acc ->
      if elem == "" do
        acc
      else
        [key, value | _] = String.split(elem, " ")
        Map.put(acc, key, value)
      end
    end)
    |> Enum.filter(fn {key, _value} ->
      String.starts_with?(key, "jellyfish_room")
    end)
    |> Map.new()
  end
end
