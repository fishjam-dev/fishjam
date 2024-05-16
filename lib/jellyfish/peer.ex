defmodule Fishjam.Peer do
  @moduledoc """
  Peer is an entity that connects to the server to publish, subscribe or publish and subscribe to tracks published by
  producers or other peers. Peer process is spawned after peer connects to the server.
  """
  use Bunch.Access

  alias Fishjam.Peer.WebRTC
  alias Fishjam.Track

  @enforce_keys [
    :id,
    :type,
    :engine_endpoint
  ]
  defstruct @enforce_keys ++
              [
                status: :disconnected,
                socket_pid: nil,
                tracks: %{},
                metadata: nil,
                last_time_connected: nil
              ]

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
          engine_endpoint: Membrane.ChildrenSpec.child_definition(),
          tracks: %{Track.id() => Track.t()},
          metadata: any(),
          last_time_connected: integer() | nil
        }

  @spec parse_type(String.t()) :: {:ok, peer()} | {:error, :invalid_type}
  def parse_type(type) do
    case type do
      "webrtc" -> {:ok, WebRTC}
      _other -> {:error, :invalid_type}
    end
  end

  @spec to_string!(module()) :: String.t()
  def to_string!(peer) do
    case peer do
      WebRTC -> "webrtc"
      _other -> raise "Invalid peer"
    end
  end

  @spec new(peer(), map()) :: {:ok, t()} | {:error, term()}
  def new(type, options) do
    id = UUID.uuid4()
    options = Map.put(options, :peer_id, id)

    with {:ok, %{endpoint: endpoint}} <- type.config(options) do
      {:ok,
       %__MODULE__{
         id: id,
         type: type,
         engine_endpoint: endpoint
       }}
    else
      {:error, _reason} = error -> error
    end
  end
end
