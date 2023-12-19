defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec.Component.RTSP.Options

  @type properties :: %{}

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()) do
      endpoint_spec =
        Map.from_struct(valid_opts)
        # OpenApiSpex will remove invalid options, so the following conversion, while ugly, is memory-safe
        |> Map.new(fn {k, v} ->
          {Atom.to_string(k) |> Macro.underscore() |> String.to_atom(), v}
        end)
        |> Map.put(:rtc_engine, engine)
        |> Map.put(:max_reconnect_attempts, :infinity)
        |> then(&struct(RTSP, &1))

      {:ok, %{endpoint: endpoint_spec, properties: %{}}}
    else
      {:error, _reason} = error ->
        error
    end
  end
end
