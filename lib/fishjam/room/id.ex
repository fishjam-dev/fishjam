defmodule Fishjam.Room.ID do
  @moduledoc """
  This module allows to generate room_id with the node name in it.
  """

  @type id :: String.t()

  @doc """
  Based on the Room ID determines to which node it belongs to.
  Returns an error if the node isn't present in the cluster.
  """
  @spec determine_node(id()) ::
          {:ok, node()} | {:error, :invalid_room_id | :node_not_found}
  def determine_node(room_id) do
    with {:ok, room_id} <- validate_room_id(room_id),
         {:ok, node_name} <- decode_node_name(room_id),
         true <- node_present_in_cluster?(node_name) do
      {:ok, String.to_existing_atom(node_name)}
    else
      {:error, :invalid_room_id} -> {:error, :invalid_room_id}
      false -> {:error, :node_not_found}
    end
  end

  @doc """
  Room ID structure resembles the one of the UUID, although the last part is replaced by encoded node name.

  ## Example:
      For node_name: "fishjam@10.0.0.1"

      iex> Fishjam.Room.ID.generate()
      "da2e-4a75-95ff-776bad2caf04-666973686a616d4031302e302e302e31"
  """
  @spec generate() :: id()
  def generate do
    UUID.uuid4()
    |> String.split("-")
    |> Enum.take(-4)
    |> Enum.concat([encoded_node_name()])
    |> Enum.join("-")
  end

  @doc """
  Depending on feature flag "request_routing_enabled":
    - if `true`, uses `generate/0` to generate room_id
    - if `false`, parses the `room_id` provided by the client
  """
  @spec generate(nil | String.t()) :: {:ok, id()} | {:error, :invalid_room_id}
  def generate(nil), do: generate(UUID.uuid4())

  def generate(room_id) do
    if Fishjam.FeatureFlags.request_routing_enabled?() do
      {:ok, generate()}
    else
      validate_room_id(room_id)
    end
  end

  defp decode_node_name(room_id) do
    room_id
    |> String.split("-")
    |> Enum.take(-1)
    |> Enum.at(0)
    |> Base.decode16(case: :lower)
    |> case do
      {:ok, node_name} -> {:ok, node_name}
      :error -> {:error, :invalid_room_id}
    end
  end

  defp encoded_node_name() do
    Node.self()
    |> Atom.to_string()
    |> Base.encode16(case: :lower)
  end

  defp node_present_in_cluster?(node_name) do
    node_name in Enum.map([Node.self() | Node.list()], &Atom.to_string/1)
  end

  defp validate_room_id(room_id) when is_binary(room_id) do
    if Regex.match?(~r/^[a-zA-Z0-9-_]+$/, room_id) do
      {:ok, room_id}
    else
      {:error, :invalid_room_id}
    end
  end

  defp validate_room_id(_room_id), do: {:error, :invalid_room_id}
end
