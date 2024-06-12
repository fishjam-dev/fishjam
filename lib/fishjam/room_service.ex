defmodule Fishjam.RoomService do
  @moduledoc """
  Behaviour for Fishjam.{Cluster, Local}.RoomService
  """

  @type cluster_error :: :invalid_room_id | :node_not_found | :rpc_failed

  @callback find_room(Room.id()) :: {:ok, pid()} | {:error, cluster_error() | :room_not_found}

  @callback get_room(Room.id()) :: {:ok, Room.t()} | {:error, cluster_error() | :room_not_found}

  @callback list_rooms() :: [Room.t()]

  @callback create_room(Room.Config.t()) ::
              {:ok, Room.t(), String.t()}
              | {:error, :rpc_failed | :room_already_exists | :room_doesnt_start}

  @callback delete_room(Room.id()) :: :ok | {:error, cluster_error() | :room_not_found}
end
