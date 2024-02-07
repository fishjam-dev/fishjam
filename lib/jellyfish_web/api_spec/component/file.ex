defmodule JellyfishWeb.ApiSpec.Component.File do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Properties do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentPropertiesFile",
      description: "Properties specific to the File component",
      type: :object,
      properties: %{
        filePath: %Schema{
          type: :string,
          description:
            "Relative path to track file. Must be either OPUS encapsulated in Ogg or raw h264"
        },
        framerate: %Schema{
          type: :integer,
          description: "Framerate of video in a file. It is only valid for video track",
          example: 30,
          nullable: true
        }
      },
      required: [:filePath, :framerate]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentOptionsFile",
      description: "Options specific to the File component",
      type: :object,
      properties: %{
        filePath: %Schema{
          type: :string,
          description: "Path to track file. Must be either OPUS encapsulated in Ogg or raw h264",
          example: "/root/video.h264"
        },
        framerate: %Schema{
          type: :integer,
          description: "Framerate of video in a file. It is only valid for video track",
          nullable: true,
          example: 30
        }
      },
      required: [:filePath]
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentFile",
    description: "Describes the File component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      # FIXME: due to cyclic imports, we can't use ApiSpec.Component.Type here
      type: %Schema{type: :string, description: "Component type", example: "file"},
      properties: Properties,
      tracks: %Schema{
        type: :array,
        items: JellyfishWeb.ApiSpec.Track,
        description: "List of all component's tracks"
      }
    },
    required: [:id, :type, :tracks]
  })
end
