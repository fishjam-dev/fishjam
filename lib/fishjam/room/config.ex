defmodule Fishjam.Room.Config do
  @moduledoc """
  Room configuration
  """

  alias Fishjam.FeatureFlags
  alias Fishjam.Room.ID

  @enforce_keys [
    :room_id,
    :max_peers,
    :video_codec,
    :webhook_url,
    :peerless_purge_timeout,
    :peer_disconnected_timeout
  ]

  defstruct @enforce_keys

  @type room_id :: String.t() | nil
  @type max_peers :: non_neg_integer() | nil
  @type video_codec :: :h264 | :vp8 | nil
  @type webhook_url :: String.t()
  @type purge_timeout :: pos_integer() | nil

  @type t :: %__MODULE__{
          room_id: room_id(),
          max_peers: max_peers(),
          video_codec: video_codec(),
          webhook_url: URI.t(),
          peerless_purge_timeout: purge_timeout(),
          peer_disconnected_timeout: purge_timeout()
        }

  @spec from_params(map()) :: {:ok, __MODULE__.t()} | {:error, atom()}
  def from_params(params) do
    room_id =
      if FeatureFlags.custom_room_name_disabled?(),
        do: ID.generate(),
        else: Map.get(params, "roomId")

    max_peers = Map.get(params, "maxPeers")
    video_codec = Map.get(params, "videoCodec")
    webhook_url = Map.get(params, "webhookUrl")
    peerless_purge_timeout = Map.get(params, "peerlessPurgeTimeout")
    peer_disconnected_timeout = Map.get(params, "peerDisconnectedTimeout")

    with {:ok, room_id} <- parse_room_id(room_id),
         :ok <- validate_max_peers(max_peers),
         {:ok, video_codec} <- codec_to_atom(video_codec),
         :ok <- validate_webhook_url(webhook_url),
         :ok <- validate_purge_timeout(peerless_purge_timeout, "peerlessPurgeTimeout"),
         :ok <- validate_purge_timeout(peer_disconnected_timeout, "peerDisconnectedTimeout") do
      {:ok,
       %__MODULE__{
         room_id: room_id,
         max_peers: max_peers,
         video_codec: video_codec,
         webhook_url: webhook_url,
         peerless_purge_timeout: peerless_purge_timeout,
         peer_disconnected_timeout: peer_disconnected_timeout
       }}
    end
  end

  defp parse_room_id(nil), do: {:ok, UUID.uuid4()}

  defp parse_room_id(room_id) when is_binary(room_id) do
    if Regex.match?(~r/^[a-zA-Z0-9-_]+$/, room_id) do
      {:ok, room_id}
    else
      {:error, :invalid_room_id}
    end
  end

  defp parse_room_id(_room_id), do: {:error, :invalid_room_id}

  defp validate_max_peers(nil), do: :ok
  defp validate_max_peers(max_peers) when is_integer(max_peers) and max_peers >= 0, do: :ok
  defp validate_max_peers(_max_peers), do: {:error, :invalid_max_peers}

  defp validate_webhook_url(nil), do: :ok

  defp validate_webhook_url(uri) do
    uri
    |> URI.parse()
    |> Map.take([:host, :path, :scheme])
    |> Enum.all?(fn {_key, value} -> not is_nil(value) end)
    |> if do
      :ok
    else
      {:error, :invalid_webhook_url}
    end
  end

  defp codec_to_atom("h264"), do: {:ok, :h264}
  defp codec_to_atom("vp8"), do: {:ok, :vp8}
  defp codec_to_atom(nil), do: {:ok, nil}
  defp codec_to_atom(_codec), do: {:error, :invalid_video_codec}

  defp validate_purge_timeout(nil, _param), do: :ok
  defp validate_purge_timeout(timeout, _param) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_purge_timeout(_timeout, param), do: {:error, :invalid_purge_timeout, param}
end
