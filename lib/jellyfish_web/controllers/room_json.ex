defmodule JellyfishWeb.RoomJSON do
  @moduledoc false

  alias JellyfishWeb.ComponentJSON
  alias JellyfishWeb.PeerJSON

  alias Jellyfish.Utils

  def index(%{rooms: rooms}) do
    %{data: rooms |> Enum.map(&data/1)}
  end

  def show(%{room: room, jellyfish_address: jellyfish_address}) do
    %{data: data(room, jellyfish_address)}
  end

  def show(%{room: room}) do
    %{data: data(room)}
  end

  def data(room), do: room_data(room)

  def data(room, jellyfish_address) do
    %{room: room_data(room), jellyfish_address: jellyfish_address}
  end

  defp room_data(room) do
    %{
      id: room.id,
      config: room.config |> Utils.camel_case_keys(),
      components: room.components |> Enum.map(&ComponentJSON.data/1),
      peers: room.peers |> Enum.map(&PeerJSON.data/1)
    }
  end
end
