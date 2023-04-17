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
        maxPeers: %Schema{
          type: :integer,
          minimum: 1,
          example: 10,
          description: "Maximum amount of peers allowed into the room",
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
        items: Component
      },
      peers: %Schema{
        type: :array,
        items: Peer
      }
    },
    required: [:id, :config, :components, :peers]
  })
end
