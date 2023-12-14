defmodule JellyfishWeb.ApiSpec.Subscription do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Origin do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Origin",
      description: "Component or Peer id",
      type: :string,
      example: "peer-id"
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
        origins: %Schema{
          type: :array,
          description:
            "List of peers and components whose tracks the HLS endpoint will subscribe to",
          items: Origin
        }
      }
    })
  end
end
