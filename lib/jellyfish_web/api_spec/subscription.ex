defmodule JellyfishWeb.ApiSpec.Subscription do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Origins do
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
            "List of peers and components ids whose tracks the HLS endpoint will subscribe to",
          items: %OpenApiSpex.Schema{type: :string}
        }
      }
    })
  end
end
