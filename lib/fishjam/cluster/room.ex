defmodule Fishjam.Cluster.Room do
  @moduledoc """
  Module responsible for managing a room present anywhere in the cluster.
  """

  @behaviour Fishjam.Room

  alias Fishjam.{Room, RPCClient}

  @local_module Fishjam.Local.Room

  @impl true
  def add_peer(room_id, peer_type, options \\ %{}),
    do: route_request(room_id, :add_peer, [room_id, peer_type, options])

  @impl true
  def set_peer_connected(room_id, peer_id, node_name, socket_pid),
    do: route_request(room_id, :set_peer_connected, [room_id, peer_id, node_name, socket_pid])

  @impl true
  def get_peer_connection_status(room_id, peer_id),
    do: route_request(room_id, :get_peer_connection_status, [room_id, peer_id])

  @impl true
  def remove_peer(room_id, peer_id),
    do: route_request(room_id, :remove_peer, [room_id, peer_id])

  @impl true
  def add_component(room_id, component_type, options \\ %{}),
    do: route_request(room_id, :add_component, [room_id, component_type, options])

  @impl true
  def remove_component(room_id, component_id),
    do: route_request(room_id, :remove_component, [room_id, component_id])

  @impl true
  def subscribe(room_id, component_id, origins),
    do: route_request(room_id, :subscribe, [room_id, component_id, origins])

  @impl true
  def dial(room_id, component_id, phone_number),
    do: route_request(room_id, :dial, [room_id, component_id, phone_number])

  @impl true
  def end_call(room_id, component_id),
    do: route_request(room_id, :end_call, [room_id, component_id])

  @impl true
  def receive_media_event(room_id, peer_id, event),
    do: route_request(room_id, :receive_media_event, [room_id, peer_id, event])

  defp route_request(room_id, fun, args) do
    with {:ok, node} <- Room.ID.determine_node(room_id),
         {:ok, result} <- RPCClient.call(node, @local_module, fun, args) do
      result
    end
  end
end
