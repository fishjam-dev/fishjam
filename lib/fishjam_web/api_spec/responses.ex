[
  {PeerDetailsResponse, "Response containing peer details and their token",
   %OpenApiSpex.Schema{
     type: :object,
     properties: %{
       peer: FishjamWeb.ApiSpec.Peer,
       token: FishjamWeb.ApiSpec.Peer.Token,
       peer_websocket_url: FishjamWeb.ApiSpec.Peer.WebSocketUrl
     },
     required: [:peer, :token]
   }},
  {RoomDetailsResponse, "Response containing room details", FishjamWeb.ApiSpec.Room},
  {RoomCreateDetailsResponse, "Response containing room details",
   %OpenApiSpex.Schema{
     type: :object,
     properties: %{
       room: FishjamWeb.ApiSpec.Room,
       fishjam_address: %OpenApiSpex.Schema{
         description:
           "Fishjam instance address where the room was created. This might be different than the address of Fishjam where the request was sent only when running a cluster of Fishjams.",
         type: :string,
         example: "fishjam1:5003"
       }
     },
     required: [:room, :fishjam_address]
   }},
  {ComponentDetailsResponse, "Response containing component details",
   FishjamWeb.ApiSpec.Component},
  {RoomsListingResponse, "Response containing list of all rooms",
   %OpenApiSpex.Schema{type: :array, items: FishjamWeb.ApiSpec.Room}},
  {RecordingListResponse, "Response containing list of all recording",
   %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}}},
  {HealthcheckResponse, "Response containing health report of Fishjam",
   FishjamWeb.ApiSpec.HealthReport}
]
|> Enum.map(fn {title, description, schema} ->
  module = Module.concat(FishjamWeb.ApiSpec, title)
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
