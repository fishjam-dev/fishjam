defmodule Jellyfish.PeersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jellyfish.Peers` context.
  """

  @doc """
  Generate a peer.
  """
  def peer_fixture(attrs \\ %{}) do
    {:ok, peer} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Jellyfish.Peers.create_peer()

    peer
  end
end
