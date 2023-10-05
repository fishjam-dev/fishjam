defmodule JellyfishWeb.Telemetry do
  @moduledoc false

  use Supervisor
  import Telemetry.Metrics
  require Logger
  alias JellyfishWeb.Telemetry.MetricsAggregator

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    metrics_ip = Application.fetch_env!(:jellyfish, :metrics_ip)
    metrics_port = Application.fetch_env!(:jellyfish, :metrics_port)

    Logger.info(
      "Starting prometheus metrics endpoint at: http://#{:inet.ntoa(metrics_ip)}:#{metrics_port}"
    )

    metrics_opts = [
      metrics: metrics(&last_value/2),
      port: metrics_port,
      plug_cowboy_opts: [ip: metrics_ip]
    ]

    children = [MetricsAggregator, {TelemetryMetricsPrometheus, metrics_opts}]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Phoenix by default uses the `summary` metric type in `LiveDashboard`,
  # but `TelemetryMetricsPrometheus` doesn't support it, so we have to use `last_value` instead.
  #
  # The metrics, events and measurements are named according to the Prometheus guidelines.
  # For more information, refer to these links:
  #   - https://prometheus.io/docs/practices/naming/
  #   - https://hexdocs.pm/telemetry_metrics_prometheus_core/1.0.0/TelemetryMetricsPrometheus.Core.html#module-naming
  def metrics(metric_type \\ &summary/2) do
    [
      # Phoenix Metrics
      metric_type.("phoenix.endpoint.start.system_time.seconds",
        event_name: [:phoenix, :endpoint, :start],
        measurement: :system_time,
        unit: {:native, :second}
      ),
      metric_type.("phoenix.endpoint.stop.duration.seconds",
        event_name: [:phoenix, :endpoint, :stop],
        measurement: :duration,
        unit: {:native, :second}
      ),
      metric_type.("phoenix.router_dispatch.start.system_time.seconds",
        event_name: [:phoenix, :router_dispatch, :start],
        measurement: :system_time,
        tags: [:route],
        unit: {:native, :second}
      ),
      metric_type.("phoenix.router_dispatch.exception.duration.seconds",
        event_name: [:phoenix, :router_dispatch, :exception],
        measurement: :duration,
        tags: [:route],
        unit: {:native, :second}
      ),
      metric_type.("phoenix.router_dispatch.stop.duration.seconds",
        event_name: [:phoenix, :router_dispatch, :stop],
        measurement: :duration,
        tags: [:route],
        unit: {:native, :second}
      ),
      metric_type.("phoenix.socket_connected.duration.seconds",
        event_name: [:phoenix, :socket_connected],
        measurement: :duration,
        unit: {:native, :second}
      ),
      metric_type.("phoenix.channel_join.duration.seconds",
        event_name: [:phoenix, :channel_join],
        measurement: :duration,
        unit: {:native, :second}
      ),
      metric_type.("phoenix.channel_handled_in.duration.seconds",
        event_name: [:phoenix, :channel_handled_in],
        measurement: :duration,
        tags: [:event],
        unit: {:native, :second}
      ),

      # VM Metrics
      metric_type.("vm.memory.total.bytes",
        event_name: [:vm, :memory],
        measurement: :total
      ),
      metric_type.("vm.total_run_queue_lengths.total", []),
      metric_type.("vm.total_run_queue_lengths.cpu", []),
      metric_type.("vm.total_run_queue_lengths.io", [])
    ]
    # Jellyfish Metrics
    |> Enum.concat(MetricsAggregator.metrics())
  end
end
