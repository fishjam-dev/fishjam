defmodule Jellyfish.Peer.WebRTC do
  @moduledoc """
  Module representing WebRTC peer.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig
  alias Membrane.WebRTC.Extension.{Mid, RepairedRid, Rid, TWCC}

  @impl true
  def config(options) do
    if not Application.get_env(:jellyfish, :webrtc_used),
      do:
        raise(
          "WebRTC peers can be used only if WEBRTC_USED environmental variable is not set to \"false\""
        )

    handshake_options = [
      client_mode: false,
      dtls_srtp: true
    ]

    simulcast? = true
    webrtc_extensions = [Mid, Rid, RepairedRid, TWCC]
    network_options = options.network_options

    {:ok,
     %WebRTC{
       rtc_engine: options.engine_pid,
       ice_name: options.peer_id,
       owner: self(),
       integrated_turn_options: network_options[:integrated_turn_options],
       integrated_turn_domain: network_options[:integrated_turn_domain],
       handshake_opts: handshake_options,
       log_metadata: [peer_id: options.peer_id],
       trace_context: nil,
       webrtc_extensions: webrtc_extensions,
       simulcast_config: %SimulcastConfig{
         enabled: simulcast?,
         initial_target_variant: fn _track -> :medium end
       }
     }}
  end
end
