defmodule JellyfishWeb.PeerView do
  use JellyfishWeb, :view

  alias Jellyfish.Peer.WebRTC

  def render("index.json", %{peers: peers}) do
    %{data: render_many(peers, __MODULE__, "peer.json")}
  end

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
      type: type
    }
  end
end
