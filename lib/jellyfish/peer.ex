defmodule Jellyfish.Peer do
  @moduledoc """
  Peer is an entity that connects to the server to publish, subscribe or publish and subscribe to tracks published by
  producers or other peers. Peer process is spawned after peer connects to the server.
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type peer_type :: :webrtc

  @typedoc """
  This module contains:
  * `id` - peer id
  * `type` - type of peer
  """
  @type t :: %__MODULE__{
          id: id,
          type: peer_type()
        }

  @spec new(peer_type :: :webrtc) :: t()
  def new(peer_type) do
    %__MODULE__{
      id: UUID.uuid4(),
      type: peer_type
    }
  end

  @spec validate_peer_type(peer_type :: String.t()) :: {:ok, peer_type()} | :error
  def validate_peer_type(peer_type) do
    case peer_type do
      "webrtc" -> {:ok, :webrtc}
      _other -> :error
    end
  end
end
