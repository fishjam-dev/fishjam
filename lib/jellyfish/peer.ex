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
  defstruct @enforce_keys

  @type id :: String.t()
  @type peer :: WebRTC

  @typedoc """
  This module contains:
  * `id` - peer id
  * `type` - type of this peer
  * `engine_endpoint` - rtc_engine endpoint for this peer
  """
  @type t :: %__MODULE__{
          id: id,
          type: peer,
          engine_endpoint: Membrane.ParentSpec.child_spec_t()
        }

  @spec parse_type(String.t()) :: {:ok, peer} | {:error, :invalid_type}
  def parse_type(type) do
    case type do
      "webrtc" -> {:ok, WebRTC}
      _other -> {:error, :invalid_type}
    end
  end

  @spec new(peer, map) :: t
  def new(type, options) do
    id = UUID.uuid4()
    options = Map.put(options, :peer_id, id)

    %__MODULE__{
      id: id,
      type: type,
      engine_endpoint: type.config(options)
    }
  end
end
