[
  {PeerDetailsResponse, "Response containing peer details and their token",
   %OpenApiSpex.Schema{
     type: :object,
     properties: %{
       peer: JellyfishWeb.ApiSpec.Peer,
       token: JellyfishWeb.ApiSpec.Peer.Token,
       peer_websocket_url: JellyfishWeb.ApiSpec.Peer.WebSocketUrl
     },
     required: [:peer, :token]
   }},
  {RoomDetailsResponse, "Response containing room details", JellyfishWeb.ApiSpec.Room},
  {RoomCreateDetailsResponse, "Response containing room details",
   %OpenApiSpex.Schema{
     type: :object,
     properties: %{
       room: JellyfishWeb.ApiSpec.Room,
       jellyfish_address: %OpenApiSpex.Schema{
         description:
           "Jellyfish instance address where the room was created. This might be different than the address of Jellyfish where the request was sent only when running a cluster of Jellyfishes.",
         type: :string,
         example: "jellyfish1:5003"
       }
     },
     required: [:room, :jellyfish_address]
   }},
  {ComponentDetailsResponse, "Response containing component details",
   JellyfishWeb.ApiSpec.Component},
  {RoomsListingResponse, "Response containing list of all rooms",
   %OpenApiSpex.Schema{type: :array, items: JellyfishWeb.ApiSpec.Room}},
  {RecordingListResponse, "Response containing list of all recording",
   %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}}},
  {HealthcheckResponse, "Response containing health report of Jellyfish",
   JellyfishWeb.ApiSpec.HealthReport}
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
