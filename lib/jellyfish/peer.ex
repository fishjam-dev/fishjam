defmodule Jellyfish.Peer do
  @moduledoc """
  Peer is an entity that connects to the server to publish, subscribe or publish and subscribe to tracks published by
  producers or other peers. Peer process is spawned after peer connects to the server.
  """

  alias Jellyfish.Peer.WebRTC

  @enforce_keys [
    :id,
    :type,
    :engine_endpoint
  ]
  defstruct @enforce_keys ++ [status: :disconnected, socket_pid: nil]

  @type id :: String.t()
  @type peer :: WebRTC
  @type status :: :connected | :disconnected

  @typedoc """
  This module contains:
  * `id` - peer id
  * `type` - type of this peer
  * `engine_endpoint` - rtc_engine endpoint for this peer
  """
  @type t :: %__MODULE__{
          id: id(),
          type: peer(),
          status: status(),
          socket_pid: pid() | nil,
          engine_endpoint: Membrane.ChildrenSpec.child_definition()
        }

  @spec parse_type(String.t()) :: {:ok, peer()} | {:error, :invalid_type}
  def parse_type(type) do
    case type do
      "webrtc" -> {:ok, WebRTC}
      _other -> {:error, :invalid_type}
    end
  end

  @spec new(peer(), map()) :: t()
  def new(type, options) do
    id = UUID.uuid4()
    options = Map.put(options, :peer_id, id)

    {:ok, endpoint} = type.config(options)

    %__MODULE__{
      id: id,
      type: type,
      engine_endpoint: endpoint
    }
  end
end
