defmodule JellyfishWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Components, Info, Paths, Schema, SecurityScheme}

  # OpenAPISpex master specification

  @impl OpenApiSpex.OpenApi
  def spec() do
    %OpenApiSpex.OpenApi{
      info: %Info{
        title: "Jellyfish Media Server",
        version: "0.1.0"
      },
      paths: Paths.from_router(JellyfishWeb.Router),
      components: %Components{
        securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}}
      },
      security: [%{"authorization" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  @spec data(String.t(), Schema.t()) :: {String.t(), String.t(), Schema.t()}
  def data(description, schema) do
    {description, "application/json", schema}
  end

  @spec error(String.t()) :: {String.t(), String.t(), module()}
  def error(description) do
    {description, "application/json", JellyfishWeb.ApiSpec.Error}
  end
end
