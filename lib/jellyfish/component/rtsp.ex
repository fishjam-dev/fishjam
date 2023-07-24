defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config
  @behaviour Jellyfish.Component

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec

  @type metadata :: %{}

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Component.RTSP.schema()) do
      component_spec =
        Map.from_struct(valid_opts)
        # OpenApiSpex will remove invalid options, so the following conversion, while ugly, is memory-safe
        |> Map.new(fn {k, v} ->
          {Atom.to_string(k) |> Macro.underscore() |> String.to_atom(), v}
        end)
        |> Map.put(:rtc_engine, engine)
        |> Map.put(:max_reconnect_attempts, :infinity)
        |> then(&struct(RTSP, &1))

      {:ok, component_spec}
    else
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def metadata(), do: %{}
end
