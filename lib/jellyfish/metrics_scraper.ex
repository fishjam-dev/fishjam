defmodule Jellyfish.MetricsScraper do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Membrane.TelemetryMetrics.Reporter
  alias Phoenix.PubSub

  @metrics_to_derive [
    :"inbound-rtp.packets",
    :"inbound-rtp.bytes_received",
    :"inbound-rtp.markers_received",
    :"outbound-rtp.packets",
    :"outbound-rtp.bytes",
    :"outbound-rtp.markers_sent",
    :"outbound-rtp.paddings_sent",
    :"ice.bytes_received",
    :"ice.bytes_sent",
    :"ice.packets_received",
    :"ice.packets_sent"
  ]

  # {metric1, metric2, result_key}
  # compound metrics are calculated as:
  # (m1_value - old_m1_value) / (m2_value - old_m2_value)
  # and saved under the `result_key`
  @compound_metrics_to_derive [
    {:"ice.buffers_processed_time", :"ice.buffers_processed", :avg_buff_proc_time}
  ]

  def start_link(scrape_interval) do
    GenServer.start_link(__MODULE__, scrape_interval, [])
  end

  @impl true
  def init(scrape_interval) do
    send(self(), :scrape)

    {:ok, %{scrape_interval: scrape_interval, prev_report: nil, prev_report_ts: 0}}
  end

  @impl true
  def handle_info(:scrape, state) do
    report = Reporter.scrape(JellyfishMetricsReporter)

    report
    |> prepare_report(state)
    |> then(&PubSub.broadcast!(Jellyfish.PubSub, "metrics", {:metrics, &1}))

    Process.send_after(self(), :scrape, state.scrape_interval)

    {:noreply,
     %{state | prev_report_ts: System.monotonic_time(:millisecond), prev_report: report}}
  end

  defp prepare_report(report, state) do
    time = System.monotonic_time(:millisecond)

    report
    |> add_time_derivative_metrics(time, state)
    |> jsonify()
    |> Jason.encode!()
  end

  defp add_time_derivative_metrics(report, time, state, path \\ []) do
    report =
      Map.new(report, fn
        {key, value} when is_map(value) ->
          {key, add_time_derivative_metrics(value, time, state, path ++ [key])}

        {key, value} ->
          {key, value}
      end)

    report =
      report
      |> Map.take(@metrics_to_derive)
      |> Enum.map(fn {key, value} when is_number(value) ->
        case get_in(state, [:prev_report | path ++ [key]]) do
          old_value when is_number(old_value) ->
            derivative = (value - old_value) * 1000 / (time - state.prev_report_ts)
            {"#{key}-per-second", derivative}

          _otherwise ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(report)

    for {m1, m2, res} <- @compound_metrics_to_derive do
      case report do
        %{^m1 => m1_v, ^m2 => m2_v} ->
          old_values = get_in(state.prev_report, path) || %{}
          old_m1_v = Map.get(old_values, m1, 0)
          old_m2_v = Map.get(old_values, m2, 0)

          metric =
            if m2_v != old_m2_v do
              (m1_v - old_m1_v) / (m2_v - old_m2_v)
            else
              0
            end

          {"#{res}", metric}

        _otherwise ->
          nil
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.into(report)
  end

  defp jsonify(report) when is_map(report) do
    Map.new(report, fn {key, value} -> {to_json_key(key), jsonify(value)} end)
  end

  defp jsonify(input), do: input

  defp to_json_key(key) when is_tuple(key) do
    key
    |> Tuple.to_list()
    |> Enum.map_join("=", &to_string/1)
  end

  defp to_json_key(key), do: to_string(key)
end
