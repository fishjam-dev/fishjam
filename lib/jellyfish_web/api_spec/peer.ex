defmodule JellyfishWeb.ApiSpec.Peer do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Type do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerType",
      description: "Peer type",
      type: :string,
      example: "webrtc"
    })
  end

  defmodule Status do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerStatus",
      description: "Informs about the peer status",
      type: :string,
      enum: ["connected", "disconnected"],
      example: "disconnected"
    })
  end

  OpenApiSpex.schema(%{
    title: "Peer",
    description: "Describes peer status",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned peer id", example: "peer-1"},
      type: Type,
      status: Status
    }
  })
end
