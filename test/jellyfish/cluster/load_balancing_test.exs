defmodule Jellyfish.Cluster.LoadBalancingTest do
  @moduledoc false

  use ExUnit.Case, async: false

  @node1 "localhost:4001"
  @node2 "localhost:4002"
  @token Application.compile_env(:jellyfish, :server_api_token)
  @headers [Authorization: "Bearer #{@token}", Accept: "Application/json; Charset=utf-8"]

  @moduletag :containerised
  @max_test_duration 400_000

  setup do
    {:ok, %{}}
  end

  @tag timeout: @max_test_duration
  test "spawning tasks on a cluster" do
    [node1, node2] =
      if Mix.env() == :test do
        Divo.Suite.start(services: [:app1, :app2]) |> on_exit()
        [@node1, @node2]
      else
        ["app1:4001", "app2:4002"]
      end

    response_body = add_room(node1)

    jellyfish_instance = get_jellyfish_address(response_body)

    assert_rooms_number_on_jellyfish(jellyfish_instance, 1)

    response_body = add_room(node1)

    jellyfish_instance = get_jellyfish_address(response_body)

    assert_rooms_number_on_jellyfish(jellyfish_instance, 1)

    assert_rooms_number_on_jellyfish(node1, 1)
    assert_rooms_number_on_jellyfish(node2, 1)
  end

  defp add_room(jellyfish_instance) do
    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{jellyfish_instance}/room", [], @headers)

    body
  end

  if Mix.env() == :test do
    defp map_jellyfish_address(jellyfish), do: jellyfish
  else
    defp map_jellyfish_address(jellyfish) do
      %{
        @node1 => "app1:4001",
        @node2 => "app2:4002"
      }
      |> Map.get(jellyfish)
    end
  end

  defp get_jellyfish_address(response_body) do
    response_body |> Jason.decode!() |> Map.get("jellyfish_address") |> map_jellyfish_address()
  end

  defp assert_rooms_number_on_jellyfish(jellyfish_instance, rooms) do
    assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
             HTTPoison.get("http://#{jellyfish_instance}/room", @headers)

    assert ^rooms = body |> Jason.decode!() |> Map.get("data") |> Enum.count()
  end
end
