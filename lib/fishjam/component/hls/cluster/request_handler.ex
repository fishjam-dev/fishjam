defmodule Fishjam.Component.HLS.Cluster.RequestHandler do
  @moduledoc """
  Module responsible for handling HLS Retrieve Content requests in the cluster.
  """

  @behaviour Fishjam.Component.HLS.RequestHandler

  alias Fishjam.{Room, RPCClient}

  @local_module Fishjam.Component.HLS.Local.RequestHandler

  @impl true
  def handle_file_request(room_id, filename),
    do: route_request(room_id, :handle_file_request, [room_id, filename])

  @impl true
  def handle_partial_request(room_id, filename),
    do: route_request(room_id, :handle_partial_request, [room_id, filename])

  @impl true
  def handle_manifest_request(room_id, partial),
    do: route_request(room_id, :handle_manifest_request, [room_id, partial])

  @impl true
  def handle_delta_manifest_request(room_id, partial),
    do: route_request(room_id, :handle_delta_manifest_request, [room_id, partial])

  defp route_request(room_id, fun, args) do
    with {:ok, node} <- Room.ID.determine_node(room_id),
         {:here?, false} <- {:here?, node == Node.self()},
         # FIXME: Fishjam addresses could easily be cached
         {:ok, address} <- RPCClient.call(node, Fishjam, :address) do
      {:redirect, address}
    else
      {:here?, true} -> apply(@local_module, fun, args)
      {:error, _reason} = error -> error
    end
  end
end
