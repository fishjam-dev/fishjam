defmodule JellyfishWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Info, Paths}

  # OpenAPISpex master specification

  @impl OpenApiSpex.OpenApi
  def spec() do
    %OpenApiSpex.OpenApi{
      info: %Info{
        title: "Jellyfish Media Server",
        version: "0.1.0"
      },
      paths: Paths.from_router(JellyfishWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
