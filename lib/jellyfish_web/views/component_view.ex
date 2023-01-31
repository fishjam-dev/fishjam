defmodule JellyfishWeb.ComponentView do
  use JellyfishWeb, :view

  def render("index.json", %{component: component}) do
    %{data: render_many(component, __MODULE__, "component.json")}
  end

  def render("show.json", %{component: component}) do
    %{data: render_one(component, __MODULE__, "component.json")}
  end

  def render("component.json", %{component: component}) do
    %{
      id: component.id,
      type: component.type
    }
  end
end
