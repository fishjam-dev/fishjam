defmodule Jellyfish.Room.Config do
  @moduledoc """
  Room configuration
  """
  @enforce_keys [:max_peers, :video_codec, :webhook_url]

  defstruct @enforce_keys

  @type max_peers :: non_neg_integer() | nil
  @type video_codec :: :h264 | :vp8 | nil
  @type webhook_url :: String.t()

  @type t :: %__MODULE__{
          max_peers: max_peers(),
          video_codec: video_codec(),
          webhook_url: URI.t()
        }

  @spec new(max_peers(), video_codec(), webhook_url()) ::
          {:ok, __MODULE__.t()} | {:error, atom()}
  def new(max_peers, video_codec, webhook_url) do
    with :ok <- validate_max_peers(max_peers),
         {:ok, video_codec} <- codec_to_atom(video_codec),
         :ok <- validate_webhook_url(webhook_url) do
      {:ok,
       %__MODULE__{
         max_peers: max_peers,
         video_codec: video_codec,
         webhook_url: webhook_url
       }}
    else
      error -> error
    end
  end

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
end
