defmodule Fishjam.Room do
  @moduledoc """
  Behaviour for Fishjam.{Cluster, Local}.Room
  """

  alias Fishjam.{Component, Peer}
  alias Fishjam.Room.ID

  @type cluster_error :: :invalid_room_id | :node_not_found | :rpc_failed

  @callback add_peer(ID.id(), Peer.peer(), map()) ::
              {:ok, Peer.t()}
              | :error
              | {:error,
                 cluster_error()
                 | {:peer_disabled_globally, String.t()}
                 | {:reached_peers_limit, String.t()}}

  @callback set_peer_connected(ID.id(), Peer.id(), Node.t(), pid()) ::
              :ok | {:error, cluster_error() | :peer_not_found | :peer_already_connected}

  @callback get_peer_connection_status(ID.id(), Peer.id()) ::
              {:ok, Peer.status()} | {:error, :peer_not_found}

  @callback remove_peer(ID.id(), Peer.id()) :: :ok | {:error, cluster_error() | :peer_not_found}

  @callback add_component(ID.id(), Component.component(), map()) ::
              {:ok, Component.t()}
              | :error
              | {:error,
                 cluster_error()
                 | {:component_disabled_globally, String.t()}
                 | :incompatible_codec
                 | {:reached_components_limit, String.t()}
                 | :file_does_not_exist
                 | :bad_parameter_framerate_for_audio
                 | :invalid_framerate
                 | :invalid_file_path
                 | :unsupported_file_type
                 | {:missing_parameter, term()}
                 | :missing_s3_credentials
                 | :overriding_credentials
                 | :overriding_path_prefix}

  @callback remove_component(ID.id(), Component.id()) ::
              :ok | {:error, cluster_error() | :component_not_found}

  @callback subscribe(ID.id(), Component.id(), [Peer.id() | Component.id()]) ::
              :ok | {:error, term()}

  @callback dial(ID.id(), Component.id(), String.t()) :: :ok | {:error, term()}

  @callback end_call(ID.id(), Component.id()) :: :ok | {:error, term()}

  @callback receive_media_event(ID.id(), Peer.id(), String.t()) :: :ok | {:error, cluster_error()}
end
