defmodule FishjamWeb.ApiSpec.Peer.WebRTC do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PeerOptionsWebRTC",
    description: "Options specific to the WebRTC peer",
    type: :object,
    properties: %{
      enableSimulcast: %Schema{
        type: :boolean,
        description: "Enables the peer to use simulcast",
        default: true
      }
    }
  })
end
