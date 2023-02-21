defmodule JellyfishWeb.ComponentView do
  use JellyfishWeb, :view

  alias Jellyfish.Component.HLS

  def render("index.json", %{component: component}) do
    %{data: render_many(component, __MODULE__, "component.json")}
  end

  def render("show.json", %{component: component}) do
    %{data: render_one(component, __MODULE__, "component.json")}
  end

  def render("component.json", %{component: component}) do
    type =
      case component.type do
        HLS -> "hls"
      end

    %{
      id: component.id,
      type: type
    }
  end
end
