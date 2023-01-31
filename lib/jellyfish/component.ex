defmodule Jellyfish.Component do
  @moduledoc """
  Component is a server side entity that can publish a track, subscribe to tracks and process them.

  Examples of components are:
    * FileReader which reads a track from a file.
    * HLSComponent which saves received tracks to HLS stream.
  """

  alias Membrane.RTC.Engine.Endpoint.HLS

  @enforce_keys [
    :id,
    :type,
    :engine_endpoint,
  ]
  defstruct @enforce_keys

  @type id :: String.t()
  @type component_type :: :file_reader | :hls

  @typedoc """
  This module contains:
  * `id` - component id
  * `type` - type of this component
  * `engine_endpoint` - engine endpoint for this component
  """
  @type t :: %__MODULE__{
          id: id,
          type: component_type(),
          engine_endpoint: struct() | atom()
        }

  @spec validate_component_type(type :: String.t()) :: {:ok, component_type()} | :error
  def validate_component_type(type) do
    case type do
      "file_reader" -> {:ok, :file_reader}
      "hls" -> {:ok, :hls}
      _other -> {:error, :invalid_component_type}
    end
  end

  @spec create_component(type :: component_type(), options :: any(), room_options :: any()) :: t()
  def create_component(component_type, _options, room_options) do
    case component_type do
      :hls -> create_hls(room_options)
      _other -> {:error, :invalid_component_type}
    end
  end

  defp create_hls(room_options) do
    endpoint = %HLS{
      rtc_engine: room_options.engine_pid,
      owner: self(),
      output_directory: "output/#{room_options.room_id}",
      target_window_duration: :infinity,
      hls_mode: :muxed_av
    }

    %__MODULE__{
      id: UUID.uuid4(),
      type: :hls,
      engine_endpoint: endpoint
    }
  end
end
