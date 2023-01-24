defmodule Jellyfish.Peer do
  @moduledoc """
  Peer is an entity that connects to the server to publish, subscribe or publish and subscribe to tracks published by
  producers or other peers. Peer process is spawned after peer connects to the server.
  """

  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys ++ [:engine_endpoint]

  @type id :: String.t()
  @type peer_type :: :webrtc

  @typedoc """
  This module contains:
  * `id` - peer id
  * `type` - type of peer
  * `engine_endpoint` - engine endpoint for this peer
  """
  @type t :: %__MODULE__{
          id: id,
          type: peer_type(),
          engine_endpoint: struct() | atom()
        }

  @spec new(peer_type :: peer_type()) :: t()
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

  @spec create_peer(peer_type :: peer_type(), any()) :: t()
  def create_peer(peer_type, options) do
    case peer_type do
      :webrtc -> add_webrtc(options)
      _other -> :error
    end
  end

  defp add_webrtc(options) do
    peer = new(:webrtc)

    network_options = options.network_options

    simulcast? = true

    handshake_opts =
      if network_options[:dtls_pkey] && network_options[:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: network_options[:dtls_pkey],
          cert: network_options[:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    webrtc_extensions = [Mid, Rid, TWCC]

    endpoint = %WebRTC{
      rtc_engine: options.engine_pid,
      ice_name: peer.id,
      owner: self(),
      integrated_turn_options: network_options[:integrated_turn_options],
      integrated_turn_domain: network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id],
      trace_context: nil,
      webrtc_extensions: webrtc_extensions,
      simulcast_config: %SimulcastConfig{
        enabled: simulcast?,
        initial_target_variant: fn _track -> :medium end
      }
    }

    %{peer | engine_endpoint: endpoint}
  end
end
