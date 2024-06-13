defmodule Fishjam.Cluster.LoadBalancingTest do
  @moduledoc false

  # These tests can only be run with `mix test.cluster.epmd` or `mix test.cluster.dns`.

  use ExUnit.Case, async: false

  alias Fishjam.PeerMessage
  alias Fishjam.PeerMessage.MediaEvent
  alias Fishjam.ServerMessage

  alias Fishjam.ServerMessage.{
    RoomCreated,
    RoomDeleted
  }

  alias FishjamWeb.WS

  @token Application.compile_env(:fishjam, :server_api_token)
  @headers [
    Authorization: "Bearer #{@token}",
    Accept: "Application/json; Charset=utf-8",
    "Content-Type": "application/json"
  ]

  @moduletag :cluster
  @max_test_duration 400_000
  @nodes ["app1:4001", "app2:4002"]

  setup do
    if Mix.env() != :test_cluster do
      raise "Load balancing tests can only be run with MIX_ENV=test_cluster"
    end

    {:ok, %{}}
  end

  @tag timeout: @max_test_duration
  test "spawning tasks on a cluster" do
    [node1, node2] = @nodes
    response_body1 = add_room(node1)

    fishjam_instance1 = get_fishjam_address(response_body1)

    assert_rooms_number_on_fishjam(fishjam_instance1, 1)

    response_body2 = add_room(node1)

    fishjam_instance2 = get_fishjam_address(response_body2)

    assert_rooms_number_on_fishjam(fishjam_instance2, 1)

    assert_rooms_number_on_fishjam(node1, 1)
    assert_rooms_number_on_fishjam(node2, 1)

    room_id = get_in(response_body1, ["data", "room", "id"])

    delete_room(fishjam_instance1, room_id)

    assert_rooms_number_on_fishjam(fishjam_instance1, 0)
    assert_rooms_number_on_fishjam(fishjam_instance2, 1)

    response_body3 = add_room(node1)
    fishjam_instance3 = get_fishjam_address(response_body3)
    assert_rooms_number_on_fishjam(fishjam_instance3, 1)

    assert_rooms_number_on_fishjam(node1, 1)
    assert_rooms_number_on_fishjam(node2, 1)
  end

  describe "peer websocket load balancing" do
    setup do
      [node1, _node2] = @nodes

      response_body = add_room(node1)
      assert %{"id" => room_id} = response_body["data"]["room"]
      fishjam_instance = get_fishjam_address(response_body)

      response_body = add_peer(fishjam_instance, room_id)
      token = response_body["data"]["token"]
      peer_id = get_in(response_body, ["data", "peer", "id"])
      other_node = @nodes |> Enum.find(&(&1 != fishjam_instance))

      on_exit(fn ->
        HTTPoison.delete("http://#{fishjam_instance}/room/#{room_id}", @headers)
      end)

      {:ok,
       %{
         room_id: room_id,
         token: token,
         room_instance: fishjam_instance,
         other_instance: other_node,
         peer_id: peer_id
       }}
    end

    @tag timeout: @max_test_duration
    test "delete room on other node", state do
      create_and_authenticate_peer(state.token, state.other_instance)
      delete_room(state.room_instance, state.room_id)
      assert_receive {:disconnected, {:remote, 1000, "Room stopped"}}, 2_000
    end

    @tag timeout: @max_test_duration
    test "delete peer on other node", state do
      create_and_authenticate_peer(state.token, state.other_instance)
      delete_peer(state.room_instance, state.room_id, state.peer_id)
      assert_receive {:disconnected, {:remote, 1000, "Peer removed"}}, 2_000
    end

    @tag timeout: @max_test_duration
    test "send connect media event", state do
      ws = create_and_authenticate_peer(state.token, state.other_instance)

      data = Jason.encode!(%{"type" => "connect", "data" => %{"metadata" => nil}})
      msg = PeerMessage.encode(%PeerMessage{content: {:media_event, %MediaEvent{data: data}}})
      :ok = WS.send_binary_frame(ws, msg)

      assert_receive %MediaEvent{data: data}, 1000
      assert %{"type" => "connected"} = Jason.decode!(data)
    end

    @tag timeout: @max_test_duration
    test "peer socket killed", state do
      ws = create_and_authenticate_peer(state.token, state.other_instance)

      Process.unlink(ws)
      Process.monitor(ws)
      Process.exit(ws, :disconnected)
      assert_receive {:DOWN, _ref, :process, ^ws, :disconnected}
      Process.sleep(500)

      room_state = get_room_state(state.room_instance, state.room_id)
      assert Enum.all?(room_state["data"]["peers"], &(&1["status"] == "disconnected"))
    end

    @tag timeout: @max_test_duration
    test "invalid token ", state do
      path = "ws://#{state.other_instance}/socket/peer/websocket"
      {:ok, ws} = WS.start_link(path, :peer)

      WS.send_auth_request(ws, "invalid" <> state.token)

      assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
    end

    @tag timeout: @max_test_duration
    test "valid token but room doesn't exist", state do
      path = "ws://#{state.other_instance}/socket/peer/websocket"

      delete_room(state.room_instance, state.room_id)

      {:ok, ws} = WS.start_link(path, :peer)
      WS.send_auth_request(ws, state.token)

      assert_receive {:disconnected, {:remote, 1000, "room not found"}}, 1000
    end

    @tag timeout: @max_test_duration
    test "send authRequest when already connected", state do
      ws = create_and_authenticate_peer(state.token, state.other_instance)

      WS.send_auth_request(ws, state.token)
      refute_receive %PeerMessage.Authenticated{}, 1000
      refute_receive {:disconnected, {:remote, 1000, _msg}}
    end

    @tag timeout: @max_test_duration
    test "two web sockets", state do
      create_and_authenticate_peer(state.token, state.other_instance)
      path = "ws://#{state.other_instance}/socket/peer/websocket"
      {:ok, ws2} = WS.start_link(path, :peer)
      WS.send_auth_request(ws2, state.token)

      assert_receive {:disconnected, {:remote, 1000, "peer already connected"}}, 1000
    end

    test "message from unauthenticated peer", state do
      create_and_authenticate_peer(state.token, state.other_instance)
      path = "ws://#{state.other_instance}/socket/peer/websocket"
      {:ok, ws} = WS.start_link(path, :peer)

      msg =
        PeerMessage.encode(%PeerMessage{
          content: {:media_event, %MediaEvent{data: "some data"}}
        })

      Process.unlink(ws)

      :ok = WS.send_binary_frame(ws, msg)

      assert_receive {:disconnected, {:remote, 1000, "unauthenticated"}}, 1000
    end
  end

  describe "server websocket load balancing" do
    setup do
      [node1, node2] = @nodes

      {:ok, %{room_instance: node1, other_instance: node2}}
    end

    test "sends a message when room gets created and deleted", state do
      server_api_token = Application.fetch_env!(:fishjam, :server_api_token)
      ws = create_and_authenticate_server(state.other_instance)

      WS.subscribe(ws, :server_notification)

      response_body1 = add_room(state.room_instance)
      fishjam_instance1 = get_fishjam_address(response_body1)
      room_id1 = get_in(response_body1, ["data", "room", "id"])
      response_body2 = add_room(state.room_instance)
      fishjam_instance2 = get_fishjam_address(response_body2)
      room_id2 = get_in(response_body2, ["data", "room", "id"])

      assert_receive %RoomCreated{room_id: ^room_id1}
      assert_receive %RoomCreated{room_id: ^room_id2}

      delete_room(fishjam_instance1, room_id1)
      delete_room(fishjam_instance2, room_id2)

      assert_receive %RoomDeleted{room_id: ^room_id1}
      assert_receive %RoomDeleted{room_id: ^room_id2}
    end
  end

  defp add_room(fishjam_instance) do
    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{fishjam_instance}/room", [], @headers)

    Jason.decode!(body)
  end

  defp add_peer(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/peer",
               Jason.encode!(%{"type" => "webrtc"}),
               @headers
             )

    Jason.decode!(body)
  end

  defp create_and_authenticate_peer(token, node) do
    path = "ws://#{node}/socket/peer/websocket"
    {:ok, ws} = WS.start_link(path, :peer)
    WS.send_auth_request(ws, token)
    assert_receive %PeerMessage.Authenticated{}, 1000

    ws
  end

  def create_and_authenticate_server(node) do
    token = Application.fetch_env!(:fishjam, :server_api_token)

    path = "ws://#{node}/socket/server/websocket"

    {:ok, ws} = WS.start_link(path, :server)
    WS.send_auth_request(ws, token)
    assert_receive %ServerMessage.Authenticated{}, 1000

    ws
  end

  defp delete_room(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204, body: body}} =
             HTTPoison.delete("http://#{fishjam_instance}/room/#{room_id}", @headers)

    body
  end

  defp delete_peer(fishjam_instance, room_id, peer_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204, body: body}} =
             HTTPoison.delete(
               "http://#{fishjam_instance}/room/#{room_id}/peer/#{peer_id}",
               @headers
             )

    body
  end

  defp get_room_state(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get(
               "http://#{fishjam_instance}/room/#{room_id}",
               @headers
             )

    Jason.decode!(body)
  end

  defp map_fishjam_address(fishjam) do
    %{
      "localhost:4001" => "app1:4001",
      "localhost:4002" => "app2:4002"
    }
    |> Map.get(fishjam)
  end

  defp get_fishjam_address(response_body) do
    response_body
    |> get_in(["data", "fishjam_address"])
    |> map_fishjam_address()
  end

  defp assert_rooms_number_on_fishjam(fishjam_instance, rooms) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{fishjam_instance}/room", @headers)

    assert ^rooms = body |> Jason.decode!() |> Map.get("data") |> Enum.count()
  end
end
