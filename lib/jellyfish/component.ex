defmodule Jellyfish.Component do
  @moduledoc """
  Component is a server side entity that can publishes a track or subscribes to tracks and process them.

  Examples of components are:
    * FileReader which reads a track from a file.
    * HLSComponent which saves received tracks to HLS stream.
  """

  alias Membrane.RTC.Engine.Endpoint.HLS

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys ++ [:engine_endpoint]

  @type id :: String.t()
  @type component_type :: :file_reader | :hls

  @typedoc """
  This module contains:
  * `id` - peer id
  * `component_type` - type of component
  * `engine_endpoint` - engine endpoint for this component
  """
  @type t :: %__MODULE__{
          id: id,
          type: component_type(),
          engine_endpoint: struct() | nil
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

  @spec create_component(component_type(), any(), any()) :: t()
  def create_component(component_type, _options, room_options) do
    case component_type do
      :hls ->
        endpoint = %HLS{
          rtc_engine: room_options.engine_pid,
          owner: self(),
          output_directory: "output/#{room_options.room_id}",
          target_window_duration: :infinity,
          hls_mode: :muxed_av
        }

        component = new(:hls)

        %{component | engine_endpoint: endpoint}

      _other ->
        :error
    end
  end
end
