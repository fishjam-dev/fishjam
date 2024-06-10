defmodule Fishjam.Cluster.LoadBalancingTest do
  @moduledoc false

  # These tests can only be run with `mix test.cluster.epmd` or `mix test.cluster.dns`.

  use ExUnit.Case, async: false

  alias Fishjam.PeerMessage.Authenticated
  alias FishjamWeb.{PeerSocket, WS}

  @token Application.compile_env(:fishjam, :server_api_token)
  @headers [
    Authorization: "Bearer #{@token}",
    Accept: "Application/json; Charset=utf-8",
    "Content-Type": "application/json"
  ]

  @moduletag :cluster
  @max_test_duration 400_000
  @auth_response %Authenticated{}
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

  @tag timeout: @max_test_duration
  test "connect peer to other node" do
    [node1, _node2] = @nodes

    response_body = add_room(node1)
    assert %{"id" => room_id} = response_body["data"]["room"]
    fishjam_instance1 = get_fishjam_address(response_body)

    response_body = add_peer(fishjam_instance1, room_id)
    token = response_body["data"]["token"]
    other_node = @nodes |> Enum.find(&(&1 != fishjam_instance1))
    create_and_authenticate(token, other_node)

    delete_room(fishjam_instance1, room_id)
    assert_receive {:disconnected, {:remote, 1000, "Room stopped"}}, 2_000
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

  def create_and_authenticate(token, node) do
    path = "ws://#{node}/socket/peer/websocket"
    {:ok, ws} = WS.start_link(path, :peer)
    WS.send_auth_request(ws, token)
    assert_receive @auth_response, 1000

    ws
  end

  defp delete_room(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204, body: body}} =
             HTTPoison.delete("http://#{fishjam_instance}/room/#{room_id}", @headers)

    body
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
