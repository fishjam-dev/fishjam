defmodule Jellyfish.Component.RTSPTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jellyfish.Component
  alias Membrane.RTC.Engine.Endpoint

  @engine_pid "placeholder"
  @jellyfish_opts %{engine_pid: @engine_pid, room_id: "example-room-id"}

  test "source_uri, default opts" do
    source_uri = "rtsp://ef36c6dff23ecc5bbe311cc880d95dc8.se:2137/does/not/matter"
    options = Map.put(@jellyfish_opts, "source_uri", source_uri)

    expected = %Endpoint.RTSP{rtc_engine: @engine_pid, source_uri: source_uri}

    {:ok, ^expected} = Component.RTSP.config(options)
  end

  test "source_uri, custom opts" do
    source_uri = "rtsp://ef36c6dff23ecc5bbe311cc880d95dc8.se:2137/does/not/matter"

    custom_opts = %{
      "source_uri" => source_uri,
      "rtp_port" => 34_567,
      "max_reconnect_attempts" => 10,
      "reconnect_delay" => 500,
      "keep_alive_interval" => 20_000,
      "pierce_nat" => false
    }

    options = Map.merge(@jellyfish_opts, custom_opts)

    expected =
      Map.new(custom_opts, fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.put(:rtc_engine, @engine_pid)
      |> then(fn x -> struct(Endpoint.RTSP, x) end)

    {:ok, ^expected} = Component.RTSP.config(options)
  end

  test "error on no source_uri" do
    {:error, {:missing_required_option, :source_uri}} = Component.RTSP.config(@jellyfish_opts)
  end
end
