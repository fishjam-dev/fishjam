defmodule FishjamWeb.ApiSpec.Component.Recording do
  @moduledoc false

  require OpenApiSpex

  alias FishjamWeb.ApiSpec.Component.HLS.S3
  alias OpenApiSpex.Schema

  defmodule Properties do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentPropertiesRecording",
      description: "Properties specific to the Recording component",
      type: :object,
      properties: %{
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the Recording component should subscribe to tracks automatically or manually",
          enum: ["auto", "manual"]
        }
      },
      required: [:subscribeMode]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentOptionsRecording",
      description: "Options specific to the Recording component",
      type: :object,
      properties: %{
        pathPrefix: %Schema{
          type: :string,
          description: "Path prefix under which all recording are stored",
          default: nil,
          nullable: true
        },
        credentials: %Schema{
          type: :object,
          description: "Credentials to AWS S3 bucket.",
          oneOf: [S3],
          nullable: true
        },
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the Recording component should subscribe to tracks automatically or manually.",
          enum: ["auto", "manual"],
          default: "auto"
        }
      },
      required: []
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentRecording",
    description: "Describes the Recording component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      # FIXME: due to cyclic imports, we can't use ApiSpec.Component.Type here
      type: %Schema{type: :string, description: "Component type", example: "recording"},
      properties: Properties,
      tracks: %Schema{
        type: :array,
        items: FishjamWeb.ApiSpec.Track,
        description: "List of all component's tracks"
      }
    },
    required: [:id, :type, :properties, :tracks]
  })
end
