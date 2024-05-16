defmodule FishjamWeb.RoomJSON do
  @moduledoc false

  alias FishjamWeb.ComponentJSON
  alias FishjamWeb.PeerJSON

  alias Fishjam.Utils.ParserJSON

  def index(%{rooms: rooms}) do
    %{data: rooms |> Enum.map(&data/1)}
  end

  def show(%{room: room, fishjam_address: fishjam_address}) do
    %{data: data(room, fishjam_address)}
  end

  def show(%{room: room}) do
    %{data: data(room)}
  end

  def data(room), do: room_data(room)

  def data(room, fishjam_address) do
    %{room: room_data(room), fishjam_address: fishjam_address}
  end

  defp room_data(room) do
    %{
      id: room.id,
      config: room.config |> Map.from_struct() |> ParserJSON.camel_case_keys(),
      components: room.components |> Enum.map(&ComponentJSON.data/1),
      peers: room.peers |> Enum.map(&PeerJSON.data/1)
    }
  end
end
