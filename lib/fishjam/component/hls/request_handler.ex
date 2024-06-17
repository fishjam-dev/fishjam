defmodule Fishjam.Component.HLS.RequestHandler do
  @moduledoc """
  Behaviour for Fishjam.Component.HLS.{Cluster, Local}.RequestHandler
  """

  alias Fishjam.Room.ID

  @type segment_sn :: non_neg_integer()
  @type partial_sn :: non_neg_integer()
  @type partial :: {segment_sn(), partial_sn()}

  @type cluster_error :: :invalid_room_id | :node_not_found | :rpc_failed

  @doc """
  Handles requests: playlists (regular hls), master playlist, headers, regular segments
  """
  @callback handle_file_request(ID.id(), String.t()) :: {:ok, binary()} | {:error, atom()}

  # TODO: uncomment once recording requests are routed
  # @doc """
  # Handles VOD requests: master playlist, headers, regular segments
  # """
  # @callback handle_recording_request(ID.id(), String.t()) :: {:ok, binary()} | {:error, atom()}

  @doc """
  Handles ll-hls partial requests
  """
  @callback handle_partial_request(ID.id(), String.t()) ::
              {:ok, binary()} | {:error, atom()}

  @doc """
  Handles manifest requests with specific partial requested (ll-hls)
  """
  @callback handle_manifest_request(ID.id(), partial()) ::
              {:ok, String.t()} | {:error, atom()}

  @doc """
  Handles delta manifest requests with specific partial requested (ll-hls)
  """
  @callback handle_delta_manifest_request(ID.id(), partial()) ::
              {:ok, String.t()} | {:error, atom()}
end
