defmodule JellyfishWeb.Integration.ServerNotificationTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint

  alias Jellyfish.PeerMessage
  alias Jellyfish.RoomService
  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    HlsPlayable,
    MetricsReport,
    PeerConnected,
    PeerDisconnected,
    RoomCrashed,
    RoomCreated,
    RoomDeleted,
    SubscribeRequest,
    SubscribeResponse
  }

  alias JellyfishWeb.{PeerSocket, ServerSocket, WS}
  alias Phoenix.PubSub

  @port 5907
  @webhook_port 2929
  @webhook_url "http://127.0.0.1:#{@webhook_port}/"
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"
  @auth_response %Authenticated{}
  @pubsub Jellyfish.PubSub

  @max_peers 1

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

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

    socket("/socket/server", ServerSocket,
      websocket: true,
      longpoll: false
    )

    socket("/socket/peer", PeerSocket,
      websocket: true,
      longpoll: false
    )
  end

  setup_all do
    assert {:ok, _pid} = Endpoint.start_link()

    webserver =
      {Plug.Cowboy, plug: WebHookPlug, scheme: :http, options: [port: @webhook_port]}

    {:ok, _pid} = Supervisor.start_link([webserver], strategy: :one_for_one)

    :ok
  end

  setup(%{conn: conn}) do
    :ok = PubSub.subscribe(@pubsub, "webhook")

    on_exit(fn ->
      server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
      conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

      conn = get(conn, ~p"/room")
      rooms = json_response(conn, :ok)["data"]

      rooms
      |> Enum.each(fn %{"id" => id} ->
        conn = delete(conn, ~p"/room/#{id}")
        assert response(conn, 204)
      end)

      :ok = PubSub.unsubscribe(@pubsub, "webhook")
    end)
  end

  test "invalid token" do
    {:ok, ws} = WS.start_link(@path, :server)
    server_api_token = "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "invalid first message" do
    {:ok, ws} = WS.start_link(@path, :server)
    msg = ServerMessage.encode(%ServerMessage{content: {:authenticated, %Authenticated{}}})

    :ok = WS.send_binary_frame(ws, msg)
    assert_receive {:disconnected, {:remote, 1000, "invalid auth request"}}, 1000
  end

  test "correct token" do
    create_and_authenticate()
  end

  test "closes on receiving an invalid message from a client" do
    ws = create_and_authenticate()

    Process.flag(:trap_exit, true)

    :ok =
      WS.send_binary_frame(
        ws,
        ServerMessage.encode(%ServerMessage{content: {:authenticated, %Authenticated{}}})
      )

    assert_receive {:disconnected, {:remote, 1003, "operation not allowed"}}, 1000
    assert_receive {:EXIT, ^ws, {:remote, 1003, "operation not allowed"}}

    Process.flag(:trap_exit, false)
  end

  test "sends HlsPlayable notification", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()
    subscribe(ws, :server_notification)
    {room_id, _peer_id, _token, conn} = add_room_and_peer(conn, server_api_token)

    {conn, hls_id} = add_hls_component(conn, room_id)
    {conn, _rtsp_id} = add_rtsp_component(conn, room_id)

    {:ok, room_pid} = RoomService.find_room(room_id)

    send(room_pid, {:playlist_playable, :video, "hls_output/#{room_id}"})
    assert_receive %HlsPlayable{room_id: ^room_id, component_id: ^hls_id}

    assert_receive {:webhook_notification,
                    %HlsPlayable{room_id: ^room_id, component_id: ^hls_id}},
                   1_000

    conn = delete(conn, ~p"/room/#{room_id}/")
    assert response(conn, :no_content)
  end

  test "doesn't send messages if not subscribed", %{conn: conn} do
    create_and_authenticate()

    trigger_notification(conn)

    refute_receive %PeerConnected{}, 200
  end

  test "sends a message when room gets created and deleted", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()

    subscribe(ws, :server_notification)

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1, webhookUrl: @webhook_url)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

    assert_receive %RoomCreated{room_id: ^room_id}
    assert_receive {:webhook_notification, %RoomCreated{room_id: ^room_id}}, 1_000

    conn = delete(conn, ~p"/room/#{room_id}")
    assert response(conn, :no_content)

    assert_receive %RoomDeleted{room_id: ^room_id}
    assert_receive {:webhook_notification, %RoomDeleted{room_id: ^room_id}}, 1_000
  end

  test "sends a message when peer connects and room is deleted", %{conn: conn} do
    {room_id, peer_id, conn} = subscribe_on_notifications_and_connect_peer(conn)

    _conn = delete(conn, ~p"/room/#{room_id}")
    assert_receive %RoomDeleted{room_id: ^room_id}

    assert_receive {:webhook_notification, %RoomDeleted{room_id: ^room_id}},
                   1_000

    refute_received %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

    refute_received {:webhook_notification,
                     %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}}
  end

  test "sends a message when peer connects and peer is removed", %{conn: conn} do
    {room_id, peer_id, conn} = subscribe_on_notifications_and_connect_peer(conn)

    conn = delete(conn, ~p"/room/#{room_id}/peer/#{peer_id}")
    assert response(conn, :no_content)

    assert_receive %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

    assert_receive {:webhook_notification,
                    %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}},
                   2_500

    _conn = delete(conn, ~p"/room/#{room_id}")
    assert_receive %RoomDeleted{room_id: ^room_id}

    assert_receive {:webhook_notification, %RoomDeleted{room_id: ^room_id}},
                   1_000
  end

  test "sends a message when peer connects and room crashes", %{conn: conn} do
    {room_id, peer_id, _conn} = subscribe_on_notifications_and_connect_peer(conn)
    {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

    Process.exit(room_pid, :kill)

    assert_receive %RoomCrashed{room_id: ^room_id}

    assert_receive {:webhook_notification, %RoomCrashed{room_id: ^room_id}},
                   1_000

    refute_received %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

    refute_received {:webhook_notification,
                     %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}}
  end

  test "sends a message when peer connects and it crashes", %{conn: conn} do
    {room_id, peer_id, conn} = subscribe_on_notifications_and_connect_peer(conn)

    {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

    state = :sys.get_state(room_pid)

    peer_socket_pid = state.peers[peer_id].socket_pid

    Process.exit(peer_socket_pid, :kill)

    assert_receive %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

    assert_receive {:webhook_notification,
                    %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}},
                   2_000

    delete(conn, ~p"/room/#{room_id}")
  end

  test "sends metrics", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()

    subscribe(ws, :server_notification)

    {room_id, peer_id, peer_token, _conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    auth_request = peer_auth_request(peer_token)
    :ok = WS.send_binary_frame(peer_ws, auth_request)

    assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}

    subscribe(ws, :metrics)
    assert_receive %MetricsReport{metrics: metrics} when metrics != "{}", 1_000

    metrics = Jason.decode!(metrics)

    [endpoint_id | _rest] = metrics["room_id=#{room_id}"] |> Map.keys()

    assert String.contains?(endpoint_id, "endpoint_id")
  end

  def subscribe_on_notifications_and_connect_peer(conn) do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()

    subscribe(ws, :server_notification)

    {room_id, peer_id, peer_token, conn} =
      add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    auth_request = peer_auth_request(peer_token)
    :ok = WS.send_binary_frame(peer_ws, auth_request)

    assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}

    assert_receive {:webhook_notification, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}},
                   1_000

    {room_id, peer_id, conn}
  end

  def create_and_authenticate() do
    token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(token)

    {:ok, ws} = WS.start_link(@path, :server)
    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive @auth_response, 1000

    ws
  end

  def subscribe(ws, event_type) do
    proto_event_type = to_proto_event_type(event_type)

    msg = %ServerMessage{
      content:
        {:subscribe_request,
         %SubscribeRequest{
           event_type: proto_event_type
         }}
    }

    :ok = WS.send_binary_frame(ws, ServerMessage.encode(msg))

    assert_receive %SubscribeResponse{event_type: ^proto_event_type} = response
    response
  end

  defp add_room_and_peer(conn, server_api_token) do
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn =
      post(conn, ~p"/room",
        maxPeers: @max_peers,
        videoCodec: "h264",
        webhookUrl: @webhook_url
      )

    assert %{"id" => room_id} = json_response(conn, :created)["data"]["room"]

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => peer_token, "peer" => %{"id" => peer_id}} =
             json_response(conn, :created)["data"]

    {room_id, peer_id, peer_token, conn}
  end

  defp add_hls_component(conn, room_id) do
    conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

    assert %{"id" => id, "metadata" => %{"playable" => false}, "type" => "hls"} =
             json_response(conn, :created)["data"]

    {conn, id}
  end

  defp add_rtsp_component(conn, room_id) do
    conn =
      post(conn, ~p"/room/#{room_id}/component", type: "rtsp", options: %{sourceUri: @source_uri})

    assert %{"id" => id, "metadata" => %{}, "type" => "rtsp"} =
             json_response(conn, :created)["data"]

    {conn, id}
  end

  defp auth_request(token) do
    ServerMessage.encode(%ServerMessage{content: {:auth_request, %AuthRequest{token: token}}})
  end

  defp peer_auth_request(token) do
    PeerMessage.encode(%PeerMessage{
      content: {:auth_request, %PeerMessage.AuthRequest{token: token}}
    })
  end

  defp trigger_notification(conn) do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    {_room_id, _peer_id, peer_token, _conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    auth_request = peer_auth_request(peer_token)
    :ok = WS.send_binary_frame(peer_ws, auth_request)
  end

  defp to_proto_event_type(:server_notification), do: :EVENT_TYPE_SERVER_NOTIFICATION
  defp to_proto_event_type(:metrics), do: :EVENT_TYPE_METRICS
end
