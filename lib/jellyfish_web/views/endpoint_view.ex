defmodule JellyfishWeb.EndpointView do
  use JellyfishWeb, :view
  alias JellyfishWeb.EndpointView

  def render("index.json", %{endpoint: endpoint}) do
    %{data: render_many(endpoint, EndpointView, "endpoint.json")}
  end

  def render("show.json", %{endpoint: endpoint}) do
    %{data: render_one(endpoint, EndpointView, "endpoint.json")}
  end

  def render("endpoint.json", %{endpoint: endpoint}) do
    %{
      id: endpoint.id,
      type: endpoint.type
    }
  end

  def render_dict(endpoints) do
    endpoints
    |> Map.values()
    |> then(&render_many(&1, EndpointView, "endpoint.json"))
  end
end
