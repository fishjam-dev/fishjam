defmodule JellyfishWeb.ApiSpec.Component.SIP do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Credentials do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Credentials",
      description: "Credentials used to authorize in SIP Provider service",
      type: :object,
      properties: %{
        address: %Schema{
          type: :string,
          description:
            "SIP provider address. Can be in the form of FQDN (my-sip-registrar.net) or IPv4 (1.2.3.4). Port can be specified e.g: 5.6.7.8:9999. If not given, the default SIP port `5060` will be assumed"
        },
        username: %Schema{type: :string, description: "Username in SIP service provider"},
        password: %Schema{type: :string, description: "Password in SIP service provider"}
      },
      required: [:address, :username, :password]
    })
  end

  defmodule Properties do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentPropertiesSIP",
      description: "Properties specific to the SIP component",
      type: :object,
      properties: %{
        credentials: %Schema{
          type: :object,
          description: "Credentials to SIP Provider",
          oneOf: [Credentials],
          nullable: false
        }
      },
      required: [:credentials]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentOptionsSIP",
      description: "Options specific to the SIP component",
      type: :object,
      properties: %{
        credentials: %Schema{
          type: :object,
          description: "Credentials to SIP Provider",
          oneOf: [Credentials],
          nullable: false
        }
      },
      required: [:credentials]
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentSIP",
    description: "Describes the SIP component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      # FIXME: due to cyclic imports, we can't use ApiSpec.Component.Type here
      type: %Schema{type: :string, description: "Component type", example: "sip"},
      properties: Properties
    },
    required: [:id, :type]
  })
end
