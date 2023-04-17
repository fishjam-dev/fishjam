[
  {PeerDetailsResponse, "Response containing peer details and their token",
   %OpenApiSpex.Schema{
     type: :object,
     properties: %{peer: JellyfishWeb.ApiSpec.Peer, token: JellyfishWeb.ApiSpec.Peer.Token},
     required: [:peer, :token]
   }},
  {RoomDetailsResponse, "Response containing room details", JellyfishWeb.ApiSpec.Room},
  {ComponentDetailsResponse, "Response containing component details",
   JellyfishWeb.ApiSpec.Component},
  {RoomsListingResponse, "Response containing list of all rooms",
   %OpenApiSpex.Schema{type: :array, items: JellyfishWeb.ApiSpec.Room}}
]
|> Enum.map(fn {title, description, schema} ->
  module = Module.concat(JellyfishWeb.ApiSpec, title)
  title_str = inspect(title)

  defmodule module do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: title_str,
      description: description,
      type: :object,
      required: [:data],
      properties: %{
        data: schema
      }
    })
  end
end)
