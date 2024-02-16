defmodule JellyfishWeb.ApiSpec.Dial do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule PhoneNumber do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DialConfig",
      description: "Dial config",
      type: :object,
      properties: %{
        phoneNumber: %Schema{
          type: :string,
          description: "Phone number on which SIP Component will call"
        }
      }
    })
  end
end
