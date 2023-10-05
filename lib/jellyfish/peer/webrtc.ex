defmodule Jellyfish.Peer.WebRTC do
  @moduledoc """
  Module representing WebRTC peer.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig
  alias Membrane.WebRTC.Extension.{Mid, RepairedRid, Rid, TWCC, VAD}
  alias Membrane.WebRTC.Track.Encoding

  alias JellyfishWeb.ApiSpec

  @impl true
  def config(options) do
    if not Application.get_env(:jellyfish, :webrtc_used),
      do:
        raise(
          "WebRTC peers can be used only if WEBRTC_USED environmental variable is not set to \"false\""
        )

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Peer.WebRTC.schema()) do
      handshake_options = [
        client_mode: false,
        dtls_srtp: true
      ]

      simulcast? = valid_opts.enableSimulcast
      webrtc_extensions = [Mid, Rid, RepairedRid, TWCC, VAD]
      network_options = options.network_options

      filter_codecs =
        case options.video_codec do
          :h264 ->
            &filter_codecs_h264/1

          :vp8 ->
            &filter_codecs_vp8/1

          nil ->
            &any_codecs/1
        end

      {:ok,
       %{
         endpoint: %WebRTC{
           rtc_engine: options.engine_pid,
           ice_name: options.peer_id,
           owner: self(),
           integrated_turn_options: network_options[:turn_options],
           integrated_turn_domain: network_options[:turn_domain],
           handshake_opts: handshake_options,
           filter_codecs: filter_codecs,
           log_metadata: [peer_id: options.peer_id],
           trace_context: nil,
           extensions: %{opus: Membrane.RTP.VAD},
           webrtc_extensions: webrtc_extensions,
           simulcast_config: %SimulcastConfig{
             enabled: simulcast?,
             initial_target_variant: fn _track -> :medium end
           },
           telemetry_label: [room_id: options.room_id]
         }
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  defp filter_codecs_h264(%Encoding{name: "H264", format_params: fmtp}) do
    import Bitwise

    # Only accept constrained baseline
    # based on RFC 6184, Table 5.
    case fmtp.profile_level_id >>> 16 do
      0x42 -> (fmtp.profile_level_id &&& 0x00_4F_00) == 0x00_40_00
      0x4D -> (fmtp.profile_level_id &&& 0x00_8F_00) == 0x00_80_00
      0x58 -> (fmtp.profile_level_id &&& 0x00_CF_00) == 0x00_C0_00
      _otherwise -> false
    end
  end

  defp filter_codecs_h264(encoding), do: filter_codecs(encoding)

  defp filter_codecs_vp8(%Encoding{name: "VP8"}), do: true
  defp filter_codecs_vp8(encoding), do: filter_codecs(encoding)

  defp any_codecs(_encoding), do: true

  defp filter_codecs(%Encoding{name: "opus"}), do: true
  defp filter_codecs(_rtp_mapping), do: false
end
