defmodule Fishjam.Cluster.RoomService do
  @moduledoc """
  Module responsible for managing rooms in the entire cluster.
  """

  @behaviour Fishjam.RoomService

  require Logger

  alias Fishjam.{FeatureFlags, Room, RPCClient}

  @local_module Fishjam.Local.RoomService

  @impl true
  def create_room(config) do
    node_resources = RPCClient.multicall(@local_module, :get_resource_usage)
    min_node = find_best_node(node_resources)

    if node_resources == [],
      do: raise("Unable to gather node resources!")

    if length(node_resources) > 1,
      do: Logger.info("Node with least used resources is #{inspect(min_node)}")

    with {:ok, result} <- RPCClient.call(min_node, @local_module, :create_room, [config]) do
      result
    end
  end

  @impl true
  def list_rooms() do
    if FeatureFlags.request_routing_enabled?() do
      RPCClient.multicall(@local_module, :list_rooms)
    else
      apply(@local_module, :list_rooms, [])
    end
  end

  @impl true
  def find_room(room_id), do: route_request(room_id, :find_room, [room_id])

  @impl true
  def get_room(room_id), do: route_request(room_id, :get_room, [room_id])

  @impl true
  def delete_room(room_id), do: route_request(room_id, :delete_room, [room_id])

  defp find_best_node(node_resources) do
    %{node: min_node} =
      Enum.min(
        node_resources,
        fn
          %{forwarded_tracks_number: forwarded_tracks, rooms_number: rooms_num1},
          %{forwarded_tracks_number: forwarded_tracks, rooms_number: rooms_num2} ->
            rooms_num1 < rooms_num2

          %{forwarded_tracks_number: forwarded_tracks1},
          %{forwarded_tracks_number: forwarded_tracks2} ->
            forwarded_tracks1 < forwarded_tracks2
        end
      )

    min_node
  end

  defp route_request(room_id, fun, args) do
    with {:ok, node} <- Room.ID.determine_node(room_id),
         {:ok, result} <- RPCClient.call(node, @local_module, fun, args) do
      result
    end
  end
end
