defmodule Jellyfish.Peer do
  @moduledoc """
  Peer is an entity that connects to the server to publish, subscribe or publish and subscribe to tracks published by
  producers or other peers. Peer process is spawned after peer connects to the server.
  """

  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig
  alias Membrane.WebRTC.Extension.{Mid, Rid, TWCC}

  @enforce_keys [
    :id,
    :type,
    :engine_endpoint
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type peer_type :: :webrtc

  @typedoc """
  This module contains:
  * `id` - peer id
  * `type` - type of this peer
  * `engine_endpoint` - engine endpoint for this peer
  """
  @type t :: %__MODULE__{
          id: id(),
          type: peer_type(),
          engine_endpoint: struct() | atom()
        }

  @spec validate_peer_type(String.t()) :: {:ok, peer_type()} | {:error, atom()}
  def validate_peer_type(type) do
    case type do
      "webrtc" -> {:ok, :webrtc}
      _other -> {:error, :invalid_type}
    end
  end

  @spec create_peer(peer_type(), any()) :: {:ok, t()} | {:error, atom()}
  def create_peer(type, options) do
    case type do
      :webrtc -> {:ok, add_webrtc(options)}
      _other -> {:error, :invalid_type}
    end
  end

  defp add_webrtc(options) do
    peer_id = UUID.uuid4()

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
      ice_name: peer_id,
      owner: self(),
      integrated_turn_options: network_options[:integrated_turn_options],
      integrated_turn_domain: network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer_id],
      trace_context: nil,
      webrtc_extensions: webrtc_extensions,
      simulcast_config: %SimulcastConfig{
        enabled: simulcast?,
        initial_target_variant: fn _track -> :medium end
      }
    }

    %__MODULE__{
      id: peer_id,
      type: :webrtc,
      engine_endpoint: endpoint
    }
  end
end
