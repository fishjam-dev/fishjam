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
      if Mix.env() == :ci do
        # On CI we don't use Divo, because we don't want to run Docker in Docker
        ["app1:4001", "app2:4002"]
      else
        Divo.Suite.start(services: [:app1, :app2]) |> on_exit()
        [@node1, @node2]
      end

    response_body1 = add_room(node1)

    jellyfish_instance1 = get_jellyfish_address(response_body1)

    assert_rooms_number_on_jellyfish(jellyfish_instance1, 1)

    response_body2 = add_room(node1)

    jellyfish_instance2 = get_jellyfish_address(response_body2)

    assert_rooms_number_on_jellyfish(jellyfish_instance2, 1)

    assert_rooms_number_on_jellyfish(node1, 1)
    assert_rooms_number_on_jellyfish(node2, 1)

    room_id = response_body1 |> Jason.decode!() |> get_in(["data", "id"])

    delete_room(jellyfish_instance1, room_id)

    assert_rooms_number_on_jellyfish(jellyfish_instance1, 0)
    assert_rooms_number_on_jellyfish(jellyfish_instance2, 1)
  end

  defp add_room(jellyfish_instance) do
    assert {:ok, %HTTPoison.Response{status_code: 201, body: body}} =
             HTTPoison.post("http://#{jellyfish_instance}/room", [], @headers)

    body
  end

  defp delete_room(jellyfish_instance, room_id) do
    assert {:ok, %HTTPoison.Response{status_code: 204, body: body}} =
             HTTPoison.delete("http://#{jellyfish_instance}/room/#{room_id}", @headers)

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
