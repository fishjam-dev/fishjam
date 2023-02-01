defmodule JellyfishWeb.RoomView do
  use JellyfishWeb, :view

  alias JellyfishWeb.ComponentView
  alias JellyfishWeb.PeerView

  def render("index.json", %{rooms: rooms}) do
    %{data: render_many(rooms, __MODULE__, "room.json")}
  end

  def render("show.json", %{room: room}) do
    %{data: render_one(room, __MODULE__, "room.json")}
  end

  def render("room.json", %{room: room}) do
    %{
      id: room.id,
      config: %{"maxPeers" => room.config.max_peers},
      components: render_many(room.components, ComponentView, "component.json"),
      peers: render_many(room.peers, PeerView, "peer.json")
    }
  end
end
