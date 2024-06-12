defmodule FishjamWeb.LocalRoomController do
  use FishjamWeb, :controller

  alias Fishjam.Local.RoomService
  alias FishjamWeb.RoomJSON

  action_fallback FishjamWeb.FallbackController

  def index(conn, _params) do
    response =
      %{rooms: RoomService.list_rooms() |> Enum.map(&maps_to_lists/1)}
      |> RoomJSON.index()
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> resp(200, response)
  end

  defp maps_to_lists(room) do
    # Values of component/peer maps also contain the ids
    components =
      room.components
      |> Enum.map(fn {_id, component} -> component end)

    peers =
      room.peers
      |> Enum.map(fn {_id, peer} -> peer end)

    %{room | components: components, peers: peers}
  end
end
