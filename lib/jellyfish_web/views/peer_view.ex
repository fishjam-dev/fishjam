defmodule JellyfishWeb.PeerView do
  use JellyfishWeb, :view

  alias Jellyfish.Peer.WebRTC

  def render("show.json", %{peer: peer}) do
    %{data: render_one(peer, __MODULE__, "peer.json")}
  end

  def render("peer.json", %{peer: peer}) do
    type =
      case peer.type do
        WebRTC -> "webrtc"
      end

    %{
      id: peer.id,
      type: type,
      status: "#{peer.status}"
    }
  end
end
