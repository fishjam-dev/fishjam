defmodule JellyfishWeb.Integration.ServerNotificationTest do
  use JellyfishWeb.ConnCase

  import Mox

  import JellyfishWeb.WS, only: [subscribe: 2]

  alias __MODULE__.Endpoint

  alias Jellyfish.Component.HLS
  alias Jellyfish.Component.HLS.Manager
  alias Jellyfish.PeerMessage
  alias Jellyfish.RoomService
  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    ComponentCrashed,
    HlsPlayable,
    HlsUploadCrashed,
    HlsUploaded,
    MetricsReport,
    PeerConnected,
    PeerDisconnected,
    PeerMetadataUpdated,
    RoomCrashed,
    RoomCreated,
    RoomDeleted,
    Track,
    TrackAdded,
    TrackRemoved
  }

  alias JellyfishWeb.{PeerSocket, ServerSocket, WS}
  alias Phoenix.PubSub

  @port 5907
  @webhook_port 2929
  @webhook_url "http://127.0.0.1:#{@webhook_port}/"
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"
  @auth_response %Authenticated{}
  @pubsub Jellyfish.PubSub

  @file_component_directory "file_component_sources"
  @fixtures_directory "test/fixtures"
  @video_source "video.h264"

  @max_peers 1

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

  @files ["manifest.m3u8", "header.mp4", "segment_1.m3u8", "segment_2.m3u8"]
  @s3_credentials %{
    access_key_id: "access_key_id",
    secret_access_key: "secret_access_key",
    region: "region",
    bucket: "bucket"
  }

  @asterisk_credentials %{
    address: "127.0.0.1:5061",
    username: "mymediaserver0",
    password: "yourpassword"
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
    Application.put_env(:jellyfish, :sip_config, sip_used?: true, sip_external_ip: "127.0.0.1")

    on_exit(fn ->
      Application.put_env(:jellyfish, :sip_config, sip_used?: false, sip_external_ip: nil)
    end)

    assert {:ok, _pid} = Endpoint.start_link()

    webserver = {Plug.Cowboy, plug: WebHookPlug, scheme: :http, options: [port: @webhook_port]}

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

  describe "establishing connection" do
    test "invalid token" do
      {:ok, ws} = WS.start_link(@path, :server)
      server_api_token = "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)
      WS.send_auth_request(ws, server_api_token)

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

    test "doesn't send messages if not subscribed", %{conn: conn} do
      create_and_authenticate()

      trigger_notification(conn)

      refute_receive %PeerConnected{}, 200
    end
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

  describe "WebRTC Peer" do
    test "sends a message when peer connects and room is deleted", %{conn: conn} do
      {room_id, peer_id, conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)

      _conn = delete(conn, ~p"/room/#{room_id}")
      assert_receive %RoomDeleted{room_id: ^room_id}

      assert_receive {:webhook_notification, %RoomDeleted{room_id: ^room_id}},
                     1_000

      refute_received %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

      refute_received {:webhook_notification,
                       %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}}
    end

    test "sends a message when peer connects and peer is removed", %{conn: conn} do
      {room_id, peer_id, conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)

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
      {room_id, peer_id, _conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)
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
      {room_id, peer_id, conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)

      {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

      state = :sys.get_state(room_pid)

      peer_socket_pid = state.peers[peer_id].socket_pid

      Process.exit(peer_socket_pid, :kill)

      assert_receive %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}

      assert_receive {:webhook_notification,
                      %PeerDisconnected{room_id: ^room_id, peer_id: ^peer_id}},
                     2_000

      state = :sys.get_state(room_pid)
      assert Map.has_key?(state.peers, peer_id)

      delete(conn, ~p"/room/#{room_id}")
    end

    test "sends message when peer metadata is updated", %{conn: conn} do
      {room_id, peer_id, _conn, peer_ws} = subscribe_on_notifications_and_connect_peer(conn)

      metadata = %{name: "Jellyuser"}
      metadata_encoded = Jason.encode!(metadata)

      media_event = %PeerMessage.MediaEvent{
        data: %{"type" => "connect", "data" => %{"metadata" => metadata}} |> Jason.encode!()
      }

      :ok =
        WS.send_binary_frame(
          peer_ws,
          PeerMessage.encode(%PeerMessage{content: {:media_event, media_event}})
        )

      assert_receive %PeerMetadataUpdated{
                       room_id: ^room_id,
                       peer_id: ^peer_id,
                       metadata: ^metadata_encoded
                     } = peer_metadata_updated

      assert_receive {:webhook_notification, ^peer_metadata_updated}, 1_000
    end
  end

  test "sends message when tracks are added or removed", %{conn: conn} do
    media_sources_directory =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@file_component_directory)
      |> Path.expand()

    File.mkdir_p!(media_sources_directory)
    File.cp_r!(@fixtures_directory, media_sources_directory)

    {room_id, _peer_id, conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)
    {conn, id} = add_file_component(conn, room_id)

    assert_receive %TrackAdded{
                     room_id: ^room_id,
                     endpoint_info: {:component_id, ^id},
                     track:
                       %Track{
                         id: _track_id,
                         type: :TRACK_TYPE_VIDEO,
                         metadata: "null"
                       } = track_info
                   } = track_added,
                   500

    assert_receive {:webhook_notification, ^track_added}, 1_000

    _conn = delete(conn, ~p"/room/#{room_id}/component/#{id}")

    assert_receive %TrackRemoved{
                     room_id: ^room_id,
                     endpoint_info: {:component_id, ^id},
                     track: ^track_info
                   } = track_removed

    assert_receive {:webhook_notification, ^track_removed}, 1_000

    :file.del_dir_r(media_sources_directory)
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

  describe "hls upload" do
    setup :verify_on_exit!
    setup :set_mox_from_context

    test "sends a message when hls was uploaded", %{conn: conn} do
      {room_id, _peer_id, _conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)
      test_hls_manager(room_id, request_no: 4, status_code: 200)

      assert_receive %HlsUploaded{room_id: ^room_id}
      assert_receive {:webhook_notification, %HlsUploaded{room_id: ^room_id}}
    end

    test "sends a message when hls upload crashed", %{conn: conn} do
      {room_id, _peer_id, _conn, _ws} = subscribe_on_notifications_and_connect_peer(conn)
      test_hls_manager(room_id, request_no: 1, status_code: 400)

      assert_receive %HlsUploadCrashed{room_id: ^room_id}
      assert_receive {:webhook_notification, %HlsUploadCrashed{room_id: ^room_id}}
    end
  end

  @tag :asterisk
  test "dial asterisk from rtc_engine", %{conn: conn} do
    {room_id, _peer_id, conn, _peer_ws} = subscribe_on_notifications_and_connect_peer(conn)

    {conn, component_id} = add_sip_component(conn, room_id)

    conn = post(conn, ~p"/sip/#{room_id}/#{component_id}/call", phoneNumber: "1230")

    assert response(conn, :created) ==
             "Successfully schedule calling phone_number: 1230"

    refute_receive %ComponentCrashed{component_id: ^component_id}, 2_500
    refute_received {:webhook_notification, %ComponentCrashed{component_id: ^component_id}}

    conn = delete(conn, ~p"/sip/#{room_id}/#{component_id}/call")

    assert response(conn, :no_content)
  end

  test "sends metrics", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()

    subscribe(ws, :server_notification)

    {room_id, peer_id, peer_token, _conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    WS.send_auth_request(peer_ws, peer_token)

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

    {room_id, peer_id, peer_token, conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    WS.send_auth_request(peer_ws, peer_token)

    assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}

    assert_receive {:webhook_notification, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}},
                   1_000

    {room_id, peer_id, conn, peer_ws}
  end

  def create_and_authenticate() do
    token = Application.fetch_env!(:jellyfish, :server_api_token)

    {:ok, ws} = WS.start_link(@path, :server)
    WS.send_auth_request(ws, token)
    assert_receive @auth_response, 1000

    ws
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

    assert %{"id" => id, "properties" => %{"playable" => false}, "type" => "hls"} =
             json_response(conn, :created)["data"]

    {conn, id}
  end

  defp add_rtsp_component(conn, room_id) do
    conn =
      post(conn, ~p"/room/#{room_id}/component", type: "rtsp", options: %{sourceUri: @source_uri})

    assert %{"id" => id, "properties" => %{}, "type" => "rtsp"} =
             json_response(conn, :created)["data"]

    {conn, id}
  end

  defp add_file_component(conn, room_id) do
    conn =
      post(conn, ~p"/room/#{room_id}/component",
        type: "file",
        options: %{filePath: @video_source}
      )

    assert %{"id" => id, "properties" => %{"filePath" => @video_source}, "type" => "file"} =
             json_response(conn, :created)["data"]

    {conn, id}
  end

  defp add_sip_component(conn, room_id) do
    conn =
      post(conn, ~p"/room/#{room_id}/component",
        type: "sip",
        options: %{registrarCredentials: @asterisk_credentials}
      )

    assert %{
             "data" => %{
               "id" => component_id,
               "type" => "sip"
             }
           } = json_response(conn, :created)

    {conn, component_id}
  end

  defp trigger_notification(conn) do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    {_room_id, _peer_id, peer_token, _conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    WS.send_auth_request(peer_ws, peer_token)
  end

  defp test_hls_manager(room_id, request_no: request_no, status_code: status_code) do
    hls_dir = HLS.output_dir(room_id, persistent: false)
    options = %{s3: @s3_credentials, persistent: false}

    File.mkdir_p!(hls_dir)
    for filename <- @files, do: :ok = hls_dir |> Path.join(filename) |> File.touch!()

    MockManager.http_mock_expect(request_no, status_code: status_code)
    pid = MockManager.start_mock_engine()

    {:ok, manager} = Manager.start(room_id, pid, hls_dir, options)
    ref = Process.monitor(manager)

    MockManager.kill_mock_engine(pid)

    assert_receive {:DOWN, ^ref, :process, ^manager, :normal}, 500
    assert {:error, _} = File.ls(hls_dir)
  end
end
