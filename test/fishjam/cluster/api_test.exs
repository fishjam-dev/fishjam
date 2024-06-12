defmodule Fishjam.Cluster.ApiTest do
  @moduledoc false

  # These tests can only be run with `mix test.cluster.epmd` or `mix test.cluster.dns`.

  use ExUnit.Case, async: false

  @token Application.compile_env(:fishjam, :server_api_token)
  @headers [Authorization: "Bearer #{@token}", Accept: "Application/json; Charset=utf-8"]
  @post_headers @headers ++ [{"Content-Type", "application/json"}]
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
  test "load-balancing and listing rooms in a cluster", %{nodes: [node1, node2]} do
    response_body1 = add_room(node1)

    fishjam_instance1 = get_fishjam_address(response_body1)

    assert_room_count_on_fishjam(fishjam_instance1, 1)

    assert_room_count_in_cluster(node1, 1)
    assert_room_count_in_cluster(node2, 1)

    response_body2 = add_room(node1)

    fishjam_instance2 = get_fishjam_address(response_body2)

    assert_room_count_on_fishjam(fishjam_instance2, 1)

    assert_room_count_on_fishjam(node1, 1)
    assert_room_count_on_fishjam(node2, 1)

    assert_room_count_in_cluster(node1, 2)
    assert_room_count_in_cluster(node2, 2)

    room_id = response_body1 |> Jason.decode!() |> get_in(["data", "room", "id"])

    delete_room(fishjam_instance1, room_id)

    assert_room_count_on_fishjam(fishjam_instance1, 0)
    assert_room_count_on_fishjam(fishjam_instance2, 1)

    assert_room_count_in_cluster(node1, 1)
    assert_room_count_in_cluster(node2, 1)

    response_body3 = add_room(node1)
    fishjam_instance3 = get_fishjam_address(response_body3)
    assert_room_count_on_fishjam(fishjam_instance3, 1)

    assert_room_count_on_fishjam(node1, 1)
    assert_room_count_on_fishjam(node2, 1)

    assert_room_count_in_cluster(node1, 2)
    assert_room_count_in_cluster(node2, 2)
  end

  @tag timeout: @max_test_duration
  test "request routing within a cluster, using room_id", %{nodes: [node1, node2]} do
    response_body1 = add_room(node1)

    room_node = get_fishjam_address(response_body1)
    other_node = if room_node == node1, do: node2, else: node1

    assert_room_count_on_fishjam(room_node, 1)
    assert_room_count_on_fishjam(other_node, 0)

    assert_room_count_in_cluster(room_node, 1)
    assert_room_count_in_cluster(other_node, 1)

    room_id = response_body1 |> Jason.decode!() |> get_in(["data", "room", "id"])

    _response_body2 = add_peer(other_node, room_id)

    assert_peer_count_in_room(room_node, room_id, 1)
    assert_peer_count_in_room(other_node, room_id, 1)

    _response_body3 = delete_room(other_node, room_id)

    assert_room_count_on_fishjam(room_node, 0)
    assert_room_count_on_fishjam(other_node, 0)

    assert_room_count_in_cluster(room_node, 0)
    assert_room_count_in_cluster(other_node, 0)
  end

  @tag timeout: @max_test_duration
  test "request routing + explicit forwarding of HLS retrieve content requests", %{
    nodes: [node1, node2]
  } do
    response_body1 = add_room(node1)

    room_node = get_fishjam_address(response_body1)
    other_node = if room_node == node1, do: node2, else: node1

    assert_room_count_on_fishjam(room_node, 1)
    assert_room_count_on_fishjam(other_node, 0)

    assert_room_count_in_cluster(room_node, 1)
    assert_room_count_in_cluster(other_node, 1)

    room_id = response_body1 |> Jason.decode!() |> get_in(["data", "room", "id"])

    _response_body2 = add_hls_component(other_node, room_id)

    _response_body3 = add_file_component(other_node, room_id)

    # Wait a while for segments and manifest to get created
    Process.sleep(10_000)

    _response_body4 = assert_successful_redirect(other_node, room_id)
  end

  defp add_room(fishjam_instance) do
    request_body = %{videoCodec: "h264"} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{fishjam_instance}/room", request_body, @post_headers)

    body
  end

  defp add_peer(fishjam_instance, room_id) do
    request_body = %{type: "webrtc", options: %{}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/peer",
               request_body,
               @post_headers
             )

    body
  end

  defp add_hls_component(fishjam_instance, room_id) do
    request_body = %{type: "hls", options: %{}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/component",
               request_body,
               @post_headers
             )

    body
  end

  defp add_file_component(fishjam_instance, room_id) do
    request_body =
      %{type: "file", options: %{filePath: "video.h264", framerate: 30}} |> Jason.encode!()

    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post(
               "http://#{fishjam_instance}/room/#{room_id}/component",
               request_body,
               @post_headers
             )

    body
  end

  defp delete_room(fishjam_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204, body: body}} =
             HTTPoison.delete("http://#{fishjam_instance}/room/#{room_id}", @headers)

    body
  end

  defp get_fishjam_address(response_body) do
    response_body
    |> Jason.decode!()
    |> get_in(["data", "fishjam_address"])
    |> map_fishjam_address()
  end

  defp map_fishjam_address(fishjam) do
    %{
      "localhost:4001" => "app1:4001",
      "localhost:4002" => "app2:4002"
    }
    |> Map.get(fishjam)
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

    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get(location, @headers)

    body
  end
end
