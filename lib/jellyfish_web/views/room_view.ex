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
    config =
      room.config
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new(fn {key, value} -> {snake_case_to_camel_case(key), value} end)

    %{
      id: room.id,
      config: config,
      components: render_many(room.components, ComponentView, "component.json"),
      peers: render_many(room.peers, PeerView, "peer.json")
    }
  end

  defp snake_case_to_camel_case(atom) do
    [first | rest] = "#{atom}" |> String.split("_")
    rest = rest |> Enum.map(&String.capitalize/1)
    Enum.join([first | rest])
  end
end
