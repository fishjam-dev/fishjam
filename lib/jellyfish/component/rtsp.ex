defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec

  @type metadata :: %{source_uri: URI.t()}

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Component.RTSP.schema()) do
      endpoint_spec =
        Map.from_struct(valid_opts)
        # OpenApiSpex will remove invalid options, so the following conversion, while ugly, is memory-safe
        |> Map.new(fn {k, v} ->
          {Atom.to_string(k) |> Macro.underscore() |> String.to_atom(), v}
        end)
        |> Map.put(:rtc_engine, engine)
        |> Map.put(:max_reconnect_attempts, :infinity)
        |> then(&struct(RTSP, &1))

      # Strip login info
      safe_uri =
        endpoint_spec.source_uri
        |> URI.parse()
        |> Map.put(:authority, nil)
        |> Map.put(:userinfo, nil)
        |> URI.to_string()

      {:ok, %{endpoint: endpoint_spec, metadata: %{source_uri: safe_uri}}}
    else
      {:error, _reason} = error -> error
    end
  end
end
