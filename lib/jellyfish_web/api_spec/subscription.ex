defmodule JellyfishWeb.ApiSpec.Subscription do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Track do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Track",
      description: "Track",
      type: :string,
      example: "track-1"
    })
  end

  defmodule Tracks do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SubscriptionConfig",
      description: "Subscription config",
      type: :object,
      properties: %{
        tracks: %Schema{
          type: :array,
          description: "List of tracks that hls endpoint will subscribe for",
          items: Track
        }
      }
    })
  end
end
