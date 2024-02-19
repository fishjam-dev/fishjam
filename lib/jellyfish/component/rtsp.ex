defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config
  use Jellyfish.Component

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec.Component.RTSP.Options

  @type properties :: %{
          sourceUri: String.t(),
          rtpPort: port(),
          reconnectDelay: non_neg_integer(),
          keepAliveInterval: non_neg_integer(),
          pierceNat: boolean()
        }

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()) do
      endpoint_spec =
        serialized_opts
        |> Map.put(:rtc_engine, engine)
        |> Map.put(:max_reconnect_attempts, :infinity)
        |> then(&struct(RTSP, &1))

      properties = serialized_opts

      {:ok, %{endpoint: endpoint_spec, properties: properties}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name}]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end
end
