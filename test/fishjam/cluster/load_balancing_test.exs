defmodule Fishjam.Cluster.LoadBalancingTest do
  @moduledoc false

  # These tests can only be run with `mix test.cluster.epmd` or `mix test.cluster.dns`.

  use ExUnit.Case, async: false

  @token Application.compile_env(:fishjam, :server_api_token)
  @headers [Authorization: "Bearer #{@token}", Accept: "Application/json; Charset=utf-8"]

  @moduletag :cluster
  @max_test_duration 400_000

  setup do
    {:ok, %{}}
  end

  @tag timeout: @max_test_duration
  test "spawning tasks on a cluster" do
    if Mix.env() != :test_cluster do
      raise "Load balancing tests can only be run with MIX_ENV=test_cluster"
    end

    [node1, node2] = ["app1:4001", "app2:4002"]

    response_body1 = add_room(node1)

    fishjam_instance1 = get_fishjam_address(response_body1)

    assert_rooms_number_on_fishjam(fishjam_instance1, 1)

    response_body2 = add_room(node1)

    fishjam_instance2 = get_fishjam_address(response_body2)

    assert_rooms_number_on_fishjam(fishjam_instance2, 1)

    assert_rooms_number_on_fishjam(node1, 1)
    assert_rooms_number_on_fishjam(node2, 1)

    room_id = response_body1 |> Jason.decode!() |> get_in(["data", "room", "id"])

    delete_room(fishjam_instance1, room_id)

    assert_rooms_number_on_fishjam(fishjam_instance1, 0)
    assert_rooms_number_on_fishjam(fishjam_instance2, 1)

    response_body3 = add_room(node1)
    fishjam_instance3 = get_fishjam_address(response_body3)
    assert_rooms_number_on_fishjam(fishjam_instance3, 1)

    assert_rooms_number_on_fishjam(node1, 1)
    assert_rooms_number_on_fishjam(node2, 1)
  end

  defp add_room(fishjam_instance) do
    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{fishjam_instance}/room", [], @headers)

    body
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
    |> Jason.decode!()
    |> get_in(["data", "fishjam_address"])
    |> map_fishjam_address()
  end

  defp assert_rooms_number_on_fishjam(fishjam_instance, rooms) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{fishjam_instance}/room", @headers)

    assert ^rooms = body |> Jason.decode!() |> Map.get("data") |> Enum.count()
  end
end
