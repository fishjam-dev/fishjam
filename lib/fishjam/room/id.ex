defmodule Fishjam.Room.ID do
  @moduledoc """
  This module allows to generate room_id with the node name in it.
  """

  @doc """
  Room ID structure resembles the one of the UUID, although the last part is replaced by node name hash.

  ## Example:
      For node_name: "fishjam@10.0.0.1"

      iex> Fishjam.Room.ID.generate()
      "da2e-4a75-95ff-776bad2caf04-666973686a616d4031302e302e302e31"
  """
  @spec generate() :: String.t()
  def generate do
    UUID.uuid4()
    |> String.split("-")
    |> Enum.take(-4)
    |> Enum.concat([encoded_node_name()])
    |> Enum.join("-")
  end

  @doc """
  Based on the Room ID determines to which node it belongs to.
  """
  @spec determine_node(String.t()) :: node()
  def determine_node(room_id) do
    room_id
    |> String.split("-")
    |> Enum.take(-1)
    |> Enum.at(0)
    |> Base.decode16!(case: :lower)
    |> String.to_atom()
  end

  defp encoded_node_name do
    Node.self()
    |> Atom.to_string()
    |> Base.encode16(case: :lower)
  end
end
