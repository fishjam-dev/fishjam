defmodule JellyfishWeb.PeerView do
  use JellyfishWeb, :view
  alias JellyfishWeb.PeerView
  alias Jellyfish.Peer

  def render("index.json", %{peers: peers}) do
    %{data: render_many(peers, PeerView, "peer.json")}
  end

  def render("show.json", %{peer: peer}) do
    %{data: render_one(peer, PeerView, "peer.json")}
  end

  def render("peer.json", %{peer: peer}) do
    %{
      id: peer.id,
      type: peer.type
    }
  end

  @spec render_dict(peers :: %{Peer.id() => Peer.t()}) :: [any()]
  def render_dict(peers) do
    peers
    |> Map.values()
    |> then(&render_many(&1, PeerView, "peer.json"))
  end
end
