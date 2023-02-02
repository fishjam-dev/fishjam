defmodule JellyfishWeb.PeerView do
  use JellyfishWeb, :view

  def render("index.json", %{peers: peers}) do
    %{data: render_many(peers, __MODULE__, "peer.json")}
  end

  def render("show.json", %{peer: peer}) do
    %{data: render_one(peer, __MODULE__, "peer.json")}
  end

  def render("peer.json", %{peer: peer}) do
    %{
      id: peer.id,
      type: peer.type
    }
  end
end
