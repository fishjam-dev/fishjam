defmodule Jellyfish.Component do
  @moduledoc """
  Component is a server side entity that can publish a track, subscribe to tracks and process them.

  Examples of components are:
    * HLSComponent which saves received tracks to HLS stream,
    * RTSPComponent which connects to a remote RTSP stream source
      and publishes the appropriate track to other Components.
  """

  alias Jellyfish.Component.{HLS, RTSP}

  @enforce_keys [
    :id,
    :type,
    :engine_endpoint
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type component :: HLS | RTSP

  @typedoc """
  This module contains:
  * `id` - component id
  * `type` - type of this component
  * `engine_endpoint` - engine endpoint for this component
  """
  @type t :: %__MODULE__{
          id: id(),
          type: component(),
          engine_endpoint: Membrane.ChildrenSpec.child_definition()
        }

  @spec parse_type(String.t()) :: {:ok, component()} | {:error, :invalid_type}
  def parse_type(type) do
    case type do
      "hls" -> {:ok, HLS}
      "rtsp" -> {:ok, RTSP}
      _other -> {:error, :invalid_type}
    end
  end

  @spec new(component(), map()) :: {:ok, t()} | {:error, term()}
  def new(type, options) do
    with {:ok, endpoint} <- type.config(options) do
      {:ok,
       %__MODULE__{
         id: UUID.uuid4(),
         type: type,
         engine_endpoint: endpoint
       }}
    else
      {:error, _reason} = error -> error
    end
  end
end
