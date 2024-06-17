defmodule Fishjam.Cluster.ApiTest do
  @moduledoc false

  # These tests can only be run with `mix test.cluster.epmd` or `mix test.cluster.dns`.

  use ExUnit.Case, async: false

  import FishjamWeb.WS, only: [subscribe: 2]

  alias Fishjam.ServerMessage.{Authenticated, HlsPlayable}
  alias FishjamWeb.WS

  @token Application.compile_env(:fishjam, :server_api_token)
  @headers [Authorization: "Bearer #{@token}", Accept: "Application/json; Charset=utf-8"]
  @post_headers @headers ++ ["Content-Type": "application/json"]
  @nodes ["app1:4001", "app2:4002"]

  @moduletag :cluster
  @max_test_duration 400_000

  setup do
    if Mix.env() != :test_cluster do
      raise "Load balancing tests can only be run with MIX_ENV=test_cluster"
    end

    # Delete all leftover rooms after each test
    on_exit(fn ->
      for node <- @nodes do
        with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
               HTTPoison.get("http://#{node}/test/local/room", @headers) do
          rooms = body |> Jason.decode!() |> Map.get("data")

          for room <- rooms, do: HTTPoison.delete("http://#{node}/room/#{room["id"]}", @headers)
        end
      end
    end)

    {:ok, %{nodes: @nodes}}
  end

  @tag timeout: @max_test_duration
  test "adding a single room in a cluster", %{nodes: [node1, _node2]} do
    %{node: room_node} = add_room(node1)

    other_node = determine_other_node(room_node)

    assert_room_counts(%{room_node => 1, other_node => 0})
  end

  @tag timeout: @max_test_duration
  test "load-balancing when adding two rooms", %{nodes: [node1, _node2]} do
    %{node: room_node1} = add_room(node1)

    other_node1 = determine_other_node(room_node1)

    assert_room_counts(%{room_node1 => 1, other_node1 => 0})

    %{node: room_node2} = add_room(node1)

    assert room_node1 != room_node2
    assert_room_counts(%{room_node1 => 1, room_node2 => 1})
  end

  @tag timeout: @max_test_duration
  test "load-balancing and request routing when deleting rooms", %{nodes: [node1, node2]} do
    %{id: room_id1, node: room_node1} = add_room(node1)
    %{node: room_node2} = add_room(node1)

    assert room_node1 != room_node2
    assert_room_counts(%{room_node1 => 1, room_node2 => 1})

    delete_room(room_node2, room_id1)

    assert_room_counts(%{room_node1 => 0, room_node2 => 1})

    %{node: room_node3} = add_room(node1)

    assert room_node3 != room_node2
    assert_room_count_on_fishjam(room_node3, 1)
    assert_room_counts(%{node1 => 1, node2 => 1})
  end

  @tag timeout: @max_test_duration
  test "request routing when adding peers", %{nodes: [node1, _node2]} do
    %{id: room_id, node: room_node} = add_room(node1)

    other_node = determine_other_node(room_node)

    assert_room_counts(%{room_node => 1, other_node => 0})

    add_peer(other_node, room_id)

    assert_peer_count_in_room(room_node, room_id, 1)
    assert_peer_count_in_room(other_node, room_id, 1)

    delete_room(other_node, room_id)

    assert_room_counts(%{room_node => 0, other_node => 0})
  end

  @tag timeout: @max_test_duration
  test "request routing + explicit forwarding of HLS retrieve content requests", %{
    nodes: [node1, _node2]
  } do
    %{id: room_id, node: room_node} = add_room(node1)

    other_node = determine_other_node(room_node)

    assert_room_counts(%{room_node => 1, other_node => 0})

    {:ok, ws} = WS.start_link("ws://#{room_node}/socket/server/websocket", :server)
    WS.send_auth_request(ws, @token)
    assert_receive %Authenticated{}, 1000
    subscribe(ws, :server_notification)

    add_hls_component(other_node, room_id)
    add_file_component(other_node, room_id)

    assert_receive %HlsPlayable{room_id: ^room_id}, 20_000
    assert_successful_redirect(other_node, room_id)
  end

  defp add_room(fishjam_instance) do
    request_body = %{videoCodec: "h264"} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{fishjam_instance}/room", request_body, @post_headers)

    room_data = body |> Jason.decode!() |> Map.fetch!("data")

    %{
      node: get_fishjam_address(room_data),
      id: get_in(room_data, ["room", "id"])
    }
  end

  defp add_peer(fishjam_instance, room_id) do
    request_body = %{type: "webrtc", options: %{}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/peer",
               request_body,
               @post_headers
             )
  end

  defp add_hls_component(fishjam_instance, room_id) do
    request_body = %{type: "hls", options: %{}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/component",
               request_body,
               @post_headers
             )
  end

  defp add_file_component(fishjam_instance, room_id) do
    request_body =
      %{type: "file", options: %{filePath: "video.h264", framerate: 30}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/component",
               request_body,
               @post_headers
             )
  end

  defp delete_room(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204}} =
             HTTPoison.delete("http://#{fishjam_instance}/room/#{room_id}", @headers)
  end

  defp get_fishjam_address(response_data) do
    response_data
    |> Map.fetch!("fishjam_address")
    |> map_fishjam_address()
  end

  defp map_fishjam_address(fishjam) do
    %{
      "localhost:4001" => "app1:4001",
      "localhost:4002" => "app2:4002"
    }
    |> Map.fetch!(fishjam)
  end

  defp assert_room_counts(instances) do
    rooms_in_cluster = instances |> Map.values() |> Enum.sum()

    for {instance, rooms} <- instances do
      assert_room_count_on_fishjam(instance, rooms)
      assert_room_count_in_cluster(instance, rooms_in_cluster)
    end
  end

  defp assert_room_count_on_fishjam(fishjam_instance, rooms) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{fishjam_instance}/test/local/room", @headers)

    assert ^rooms = body |> Jason.decode!() |> Map.get("data") |> Enum.count()
  end

  defp assert_room_count_in_cluster(fishjam_instance, rooms) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{fishjam_instance}/room", @headers)

    assert ^rooms = body |> Jason.decode!() |> Map.get("data") |> Enum.count()
  end

  defp assert_peer_count_in_room(fishjam_instance, room_id, peers) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{fishjam_instance}/room/#{room_id}", @headers)

    assert ^peers = body |> Jason.decode!() |> get_in(["data", "peers"]) |> Enum.count()
  end

  defp assert_successful_redirect(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} =
             HTTPoison.get("http://#{fishjam_instance}/hls/#{room_id}/index.m3u8", @headers)

    assert {"location", location} = List.keyfind(headers, "location", 0)

    location_uri = URI.parse(location)
    fishjam_address = map_fishjam_address("#{location_uri.host}:#{location_uri.port}")

    location =
      "#{location_uri.scheme}://#{fishjam_address}"
      |> URI.parse()
      |> Map.put(:path, location_uri.path)
      |> URI.to_string()

    assert {:ok, %HTTPoison.Response{status_code: 200}} = HTTPoison.get(location, @headers)
  end

  defp determine_other_node(room_node) do
    Enum.find(@nodes, &(&1 != room_node))
  end
end
