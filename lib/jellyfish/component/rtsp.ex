defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id]) |> Map.put(:rtc_engine, engine)

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Component.RTSP.schema()) do
      {:ok, struct(RTSP, valid_opts)}
    else
      {:error, _reason} = error -> error
    end
  end
end
