defmodule Jellyfish.Endpoint do
  @moduledoc """
  Endpoint is a server side entity that can publishes a track or subscribes to tracks and process them.

  Examples of endpoints are:
    * FileReader which reads a track from a file.
    * HLSEndpoint which saves received tracks to HLS stream.
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type endpoint_type :: :file_reader | :hls_endpoint

  @typedoc """
  This module contains:
  * `id` - peer id
  * `endpoint_type` - type of endpoint
  """
  @type t :: %__MODULE__{
          id: id,
          type: endpoint_type()
        }

  @spec new(endpoint_type :: atom()) :: t()
  def new(endpoint_type) do
    %__MODULE__{
      id: UUID.uuid4(),
      type: endpoint_type
    }
  end

  @spec validate_endpoint_type(endpoint_type :: String.t()) :: {:ok, endpoint_type()} | :error
  def validate_endpoint_type(endpoint_type) do
    case endpoint_type do
      "file_reader" -> {:ok, :file_reader}
      "hls" -> {:ok, :hls}
      _other -> :error
    end
  end
end
