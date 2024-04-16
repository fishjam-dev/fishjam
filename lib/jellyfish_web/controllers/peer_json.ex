defmodule JellyfishWeb.PeerJSON do
  @moduledoc false
  alias Jellyfish.Peer.WebRTC

  def show(%{peer: peer, token: token, peer_websocket_url: ws_url}) do
    %{data: %{peer: data(peer), token: token, peer_websocket_url: ws_url}}
  end

  def show(%{peer: peer}) do
    %{data: data(peer)}
  end

  def data(peer) do
    type =
      case peer.type do
        WebRTC -> "webrtc"
      end

    %{
      id: peer.id,
      type: type,
      status: "#{peer.status}",
      tracks: peer.tracks |> Map.values() |> Enum.map(&Map.from_struct/1),
      metadata: peer.metadata
    }
  end
end
