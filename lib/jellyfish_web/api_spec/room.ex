defmodule JellyfishWeb.ApiSpec.Room do
  require OpenApiSpex

  alias JellyfishWeb.ApiSpec.{Component, Peer}
  alias OpenApiSpex.Schema

  defmodule Config do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RoomConfig",
      description: "Room configuration",
      type: :object,
      properties: %{
        roomID: %Schema{
          type: :string,
          description:
            "Custom id used for identifying room within Jellyfish. Must be unique across all rooms. If not provided, random UUID is generated.",
          nullable: true
        },
        maxPeers: %Schema{
          type: :integer,
          minimum: 1,
          example: 10,
          description: "Maximum amount of peers allowed into the room",
          nullable: true
        },
        videoCodec: %Schema{
          description: "Enforces video codec for each peer in the room",
          type: :string,
          enum: ["h264", "vp8"],
          nullable: true
        },
        webhookUrl: %Schema{
          description: "URL where Jellyfish notifications will be sent",
          type: :string,
          example: "https://backend.address.com/jellyfish-notifications-endpoint",
          nullable: true
        }
      }
    })
  end

  OpenApiSpex.schema(%{
    title: "Room",
    description: "Description of the room state",
    type: :object,
    properties: %{
      id: %Schema{description: "Room ID", type: :string, example: "room-1"},
      config: Config,
      components: %Schema{
        type: :array,
        items: Component,
        description: "List of all components"
      },
      peers: %Schema{
        type: :array,
        items: Peer,
        description: "List of all peers"
      }
    },
    required: [:id, :config, :components, :peers]
  })
end
