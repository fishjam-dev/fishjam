defmodule Jellyfish.Component do
  @moduledoc """
  Component is a server side entity that can publishes a track or subscribes to tracks and process them.

  Examples of components are:
    * FileReader which reads a track from a file.
    * HLSComponent which saves received tracks to HLS stream.
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type component_type :: :file_reader | :hls_component

  @typedoc """
  This module contains:
  * `id` - peer id
  * `component_type` - type of component
  """
  @type t :: %__MODULE__{
          id: id,
          type: component_type()
        }

  @spec new(component_type :: atom()) :: t()
  def new(component_type) do
    %__MODULE__{
      id: UUID.uuid4(),
      type: component_type
    }
  end

  @spec validate_component_type(component_type :: String.t()) ::
          {:ok, component_type()} | :error
  def validate_component_type(component_type) do
    case component_type do
      "file_reader" -> {:ok, :file_reader}
      "hls" -> {:ok, :hls}
      _other -> :error
    end
  end
end
