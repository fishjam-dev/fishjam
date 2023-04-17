defmodule Jellyfish.Component.RTSPTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jellyfish.Component
  alias Membrane.RTC.Engine.Endpoint

  @engine_pid "placeholder"
  @source_uri "rtsp://ef36c6dff23ecc5bbe311cc880d95dc8.se:2137/does/not/matter"
  @jellyfish_opts %{engine_pid: @engine_pid, room_id: "example-room-id"}

  test "sourceUri, default opts" do
    options = Map.put(@jellyfish_opts, "sourceUri", @source_uri)

    expected = %Endpoint.RTSP{rtc_engine: @engine_pid, source_uri: @source_uri}

    {:ok, ^expected} = Component.RTSP.config(options)
  end

  test "sourceUri, custom opts" do
    custom_opts = %{
      "sourceUri" => @source_uri,
      "rtpPort" => 34_567,
      "maxReconnectAttempts" => 10,
      "reconnectDelay" => 500,
      "keepAliveInterval" => 20_000,
      "pierceNat" => false
    }

    options = Map.merge(@jellyfish_opts, custom_opts)

    expected =
      Map.new(custom_opts, fn {k, v} -> {Macro.underscore(k) |> String.to_atom(), v} end)
      |> Map.put(:rtc_engine, @engine_pid)
      |> then(&struct(Endpoint.RTSP, &1))

    {:ok, ^expected} = Component.RTSP.config(options)
  end

  test "error on no sourceUri" do
    expected_reason = [
      %OpenApiSpex.Cast.Error{
        reason: :missing_field,
        value: %{},
        format: nil,
        type: nil,
        name: :sourceUri,
        path: [:sourceUri],
        length: 0,
        meta: %{}
      }
    ]

    {:error, ^expected_reason} = Component.RTSP.config(@jellyfish_opts)
  end
end
