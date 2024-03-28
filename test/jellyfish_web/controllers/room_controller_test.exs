defmodule JellyfishWeb.RoomControllerTest do
  use JellyfishWeb.ConnCase, async: false

  import OpenApiSpex.TestAssertions

  alias __MODULE__.Endpoint

  alias Jellyfish.PeerMessage.Authenticated
  alias Jellyfish.RoomService
  alias JellyfishWeb.{PeerSocket, WS}

  @schema JellyfishWeb.ApiSpec.spec()

  @purge_timeout_s 3
  @purge_timeout_ms @purge_timeout_s * 1000

  @port 5910
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
    delete_all_rooms()
    assert {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    Klotho.Mock.reset()
    Klotho.Mock.freeze()

    on_exit(fn -> delete_all_rooms() end)

    [conn: conn]
  end

  describe "auth" do
    setup %{conn: conn} do
      conn = delete_req_header(conn, "authorization")
      [conn: conn]
    end

    test "invalid token", %{conn: conn} do
      invalid_server_api_token =
        "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)

      conn = put_req_header(conn, "authorization", "Bearer " <> invalid_server_api_token)

      conn = post(conn, ~p"/room", maxPeers: 10)

      response = json_response(conn, :unauthorized)

      assert_response_schema(response, "Error", @schema)
    end

    test "missing token", %{conn: conn} do
      conn = post(conn, ~p"/room", maxPeers: 10)

      response = json_response(conn, :unauthorized)

      assert_response_schema(response, "Error", @schema)
    end

    test "correct token", %{conn: conn} do
      server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
      conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

      conn = post(conn, ~p"/room", maxPeers: 10)
      json_response(conn, :created)
    end
  end

  describe "index" do
    test "lists all rooms", %{conn: conn} do
      conn = get(conn, ~p"/room")
      response = json_response(conn, :ok)
      assert Enum.empty?(response["data"])

      conn = post(conn, ~p"/room", maxPeers: 10)

      conn = get(conn, ~p"/room")
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomsListingResponse", @schema)

      assert length(response["data"]) == 1
    end
  end

  describe "create room" do
    test "renders room when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/room", maxPeers: 10, peerlessPurgeTimeout: 60)
      assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

      conn = get(conn, ~p"/room/#{id}")
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomDetailsResponse", @schema)

      assert %{
               "id" => ^id,
               "config" => %{"maxPeers" => 10, "peerlessPurgeTimeout" => 60},
               "components" => [],
               "peers" => []
             } = response["data"]
    end

    test "renders room when data is valid, custom room_id + max_peers and peerless_purge_timeout not present",
         %{conn: conn} do
      room_id = UUID.uuid4()

      conn = post(conn, ~p"/room", roomId: room_id)
      json_response(conn, :created)

      conn = get(conn, ~p"/room/#{room_id}")
      response = json_response(conn, :ok)
      assert_response_schema(response, "RoomDetailsResponse", @schema)

      assert %{
               "id" => ^room_id,
               "config" => %{"maxPeers" => nil, "peerlessPurgeTimeout" => nil},
               "components" => [],
               "peers" => []
             } = response["data"]
    end

    test "renders error when adding two rooms with same room_id", %{conn: conn} do
      room_id = UUID.uuid4()

      conn = post(conn, ~p"/room", roomId: room_id)
      json_response(conn, :created)

      conn = post(conn, ~p"/room", roomId: room_id)

      assert json_response(conn, :bad_request)["errors"] ==
               "Cannot add room with id \"#{room_id}\" - room already exists"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/room", maxPeers: "nan")

      assert json_response(conn, :bad_request)["errors"] ==
               "Expected maxPeers to be a number, got: nan"

      conn = post(conn, ~p"/room", videoCodec: "nan")

      assert json_response(conn, :bad_request)["errors"] ==
               "Expected videoCodec to be 'h264' or 'vp8', got: nan"

      conn = post(conn, ~p"/room", webhookUrl: "nan")

      assert json_response(conn, :bad_request)["errors"] ==
               "Expected webhookUrl to be valid URL, got: nan"

      conn = post(conn, ~p"/room", peerlessPurgeTimeout: "nan")

      assert json_response(conn, :bad_request)["errors"] ==
               "Expected peerlessPurgeTimeout to be a positive integer, got: nan"

      conn = post(conn, ~p"/room", roomId: "test/path")

      assert json_response(conn, :bad_request)["errors"] ==
               "Cannot add room with id \"test/path\" - roomId accepts only alphanumeric characters"
    end
  end

  describe "peerless purge" do
    setup %{conn: conn} do
      conn = post(conn, ~p"/room", peerlessPurgeTimeout: @purge_timeout_s)
      assert %{"id" => id} = json_response(conn, :created)["data"]["room"]
      %{conn: conn, id: id}
    end

    test "happens if peers never joined", %{conn: conn, id: id} do
      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")
      assert response(conn, :created)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)

      conn = get(conn, ~p"/room")
      assert Enum.empty?(json_response(conn, :ok)["data"])
    end

    test "happens if peer joined, then removed", %{conn: conn, id: id} do
      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")

      assert %{"token" => token, "peer" => %{"id" => peer_id}} =
               json_response(conn, :created)["data"]

      connect_peer(token)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)

      conn = delete(conn, ~p"/room/#{id}/peer/#{peer_id}")
      assert response(conn, :no_content)
      Klotho.Mock.warp_by(@purge_timeout_ms + 10)

      conn = get(conn, ~p"/room")
      assert Enum.empty?(json_response(conn, :ok)["data"])
    end

    test "happens if peer joined, then disconnected", %{conn: conn, id: id} do
      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")
      assert %{"token" => token} = json_response(conn, :created)["data"]

      ws = connect_peer(token)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)

      GenServer.stop(ws)
      Process.sleep(10)

      conn = get(conn, ~p"/room/#{id}")

      assert %{"status" => "disconnected"} =
               json_response(conn, :ok)["data"]["peers"] |> List.first()

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)

      conn = get(conn, ~p"/room")
      assert Enum.empty?(json_response(conn, :ok)["data"])
    end

    test "does not happen if peers rejoined quickly", %{conn: conn, id: id} do
      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")
      assert %{"token" => token} = json_response(conn, :created)["data"]

      ws = connect_peer(token)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)

      GenServer.stop(ws)
      Process.sleep(10)
      conn = get(conn, ~p"/room/#{id}")

      assert %{"status" => "disconnected"} =
               json_response(conn, :ok)["data"]["peers"] |> List.first()

      Klotho.Mock.warp_by(@purge_timeout_ms |> div(2))
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)

      connect_peer(token)
      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)
    end

    test "timeout is reset if another peer is created and removed", %{conn: conn, id: id} do
      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")
      assert %{"peer" => %{"id" => peer_id}} = json_response(conn, :created)["data"]

      conn = delete(conn, ~p"/room/#{id}/peer/#{peer_id}")
      assert response(conn, :no_content)

      Klotho.Mock.warp_by(@purge_timeout_ms |> div(2))

      conn = post(conn, ~p"/room/#{id}/peer", type: "webrtc")
      assert response(conn, :created)

      Klotho.Mock.warp_by(@purge_timeout_ms |> div(2) |> Kernel.+(10))
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)

      Klotho.Mock.warp_by(@purge_timeout_ms |> div(2))
      conn = get(conn, ~p"/room")
      assert Enum.empty?(json_response(conn, :ok)["data"])
    end

    test "does not happen when not configured", %{conn: conn} do
      conn = post(conn, ~p"/room")
      assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      conn = get(conn, ~p"/room/#{id}")
      assert response(conn, :ok)
    end
  end

  describe "delete room" do
    setup [:create_room]

    test "deletes chosen room", %{conn: conn, room_id: room_id} do
      room_pid = RoomService.find_room!(room_id)
      %{engine_pid: engine_pid} = :sys.get_state(room_pid)

      assert Process.alive?(room_pid)
      assert Process.alive?(engine_pid)

      Process.monitor(room_pid)
      Process.monitor(engine_pid)

      conn = delete(conn, ~p"/room/#{room_id}")
      assert response(conn, :no_content)

      assert_receive({:DOWN, _ref, :process, ^room_pid, :normal})
      assert_receive({:DOWN, _ref, :process, ^engine_pid, :normal})

      conn = get(conn, ~p"/room/#{room_id}")
      assert json_response(conn, :not_found) == %{"errors" => "Room #{room_id} does not exist"}
    end

    test "returns 404 if room doesn't exists", %{conn: conn} do
      conn = delete(conn, ~p"/room/#{"invalid_room"}")
      assert response(conn, :not_found)
    end
  end

  describe "room crashing" do
    setup [:create_room]

    test "roomService removes room on crash", %{room_id: room_id} = state do
      %{room_id: room2_id} = create_room(state)

      room_pid = RoomService.find_room!(room_id)
      %{engine_pid: engine_pid} = :sys.get_state(room_pid)

      assert Process.alive?(engine_pid)
      Process.monitor(engine_pid)

      :erlang.trace(Process.whereis(RoomService), true, [:receive])

      assert true = Process.exit(room_pid, :error)

      assert_receive({:trace, _pid, :receive, {:DOWN, _ref, :process, ^room_pid, :error}})
      assert_receive({:DOWN, _ref, :process, ^engine_pid, :error})

      # Shouldn't throw an error as in ets should be only living processes
      rooms = RoomService.list_rooms()
      assert Enum.any?(rooms, &(&1.id == room2_id))
      assert Enum.all?(rooms, &(&1.id != room_id))
    end

    test "room closes on engine crash", %{room_id: room_id} = state do
      %{room_id: room2_id} = create_room(state)

      room_pid = RoomService.find_room!(room_id)

      :erlang.trace(Process.whereis(RoomService), true, [:receive])

      %{engine_pid: engine_pid} = :sys.get_state(room_pid)

      assert true = Process.exit(engine_pid, :error)

      assert_receive({:trace, _pid, :receive, {:DOWN, _ref, :process, ^room_pid, :error}})

      # Shouldn't throw an error as in ets should be only living processes
      rooms = RoomService.list_rooms()
      assert Enum.any?(rooms, &(&1.id == room2_id))
      assert Enum.all?(rooms, &(&1.id != room_id))
    end
  end

  defp create_room(state) do
    conn = post(state.conn, ~p"/room")
    assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

    %{room_id: id}
  end

  defp delete_all_rooms() do
    token = Application.fetch_env!(:jellyfish, :server_api_token)
    headers = [Authorization: "Bearer #{token}", Accept: "Application/json; Charset=utf-8"]

    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://127.0.0.1:4002/room", headers)

    rooms = Jason.decode!(body)["data"]

    Enum.each(rooms, fn room ->
      assert {:ok, %HTTPoison.Response{status_code: 204}} =
               HTTPoison.delete("http://127.0.0.1:4002/room/#{room["id"]}", headers)
    end)
  end

  def connect_peer(token) do
    {:ok, ws} = WS.start_link(@path, :peer)
    WS.send_auth_request(ws, token)
    assert_receive @auth_response

    ws
  end
end
