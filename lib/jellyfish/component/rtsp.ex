defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.RTSP

  @required_opts [:source_uri]
  @optional_opts [
    :rtp_port,
    :max_reconnect_attempts,
    :reconnect_delay,
    :keep_alive_interval,
    :pierce_nat
  ]

  @impl true
  def config(%{engine_pid: engine} = options) do
    with {:ok, config_opts} <-
           Enum.reduce_while(@required_opts, {:ok, %{rtc_engine: engine}}, fn key, acc ->
             parse_required_opt(acc, options, key)
           end) do
      {:ok,
       Enum.reduce(@optional_opts, struct(RTSP, config_opts), fn key, acc ->
         parse_optional_opt(acc, options, key)
       end)}
    else
      {:error, _reason} = error -> error
    end
  end

  defp parse_required_opt({:ok, config}, options, key) do
    do_parse_opt(config, options, key, true)
  end

  defp parse_optional_opt(config, options, key) do
    do_parse_opt(config, options, key, false)
  end

  defp do_parse_opt(config, options, key, required?) do
    key_str = to_string(key)
    key_present? = Map.has_key?(options, key_str)
    config = if key_present?, do: Map.put(config, key, Map.get(options, key_str)), else: config

    if required? do
      if key_present?,
        do: {:cont, {:ok, config}},
        else: {:halt, {:error, {:missing_required_option, key}}}
    else
      config
    end
  end
end
