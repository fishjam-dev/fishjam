defmodule JellyfishWeb.RoomView do
  use JellyfishWeb, :view
  alias JellyfishWeb.RoomView
  alias JellyfishWeb.PeerView
  alias JellyfishWeb.EndpointView

  def render("index.json", %{rooms: rooms}) do
    %{data: render_many(rooms, RoomView, "room.json")}
  end

  def render("show.json", %{room: room}) do
    %{data: render_one(room, RoomView, "room.json")}
  end

  def render("room.json", %{room: room}) do
    %{
      id: room.id,
      config: room.config,
      endpoints: EndpointView.render_dict(room.endpoints),
      peers: PeerView.render_dict(room.peers)
    }
  end
end
