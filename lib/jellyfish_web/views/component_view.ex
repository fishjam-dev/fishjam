defmodule JellyfishWeb.ComponentView do
  use JellyfishWeb, :view
  alias JellyfishWeb.ComponentView

  def render("index.json", %{component: component}) do
    %{data: render_many(component, ComponentView, "component.json")}
  end

  def render("show.json", %{component: component}) do
    %{data: render_one(component, ComponentView, "component.json")}
  end

  def render("component.json", %{component: component}) do
    %{
      id: component.id,
      type: component.type
    }
  end

  def render_dict(components) do
    components
    |> Map.values()
    |> then(&render_many(&1, ComponentView, "component.json"))
  end
end
