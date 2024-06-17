defmodule FishjamWeb.Telemetry do
  @moduledoc false

  use Supervisor
  import Telemetry.Metrics
  require Logger

  @ice_received_event [Membrane.ICE, :ice, :payload, :received]
  @ice_sent_event [Membrane.ICE, :ice, :payload, :sent]
  @http_request_event [:fishjam_web, :request]
  @http_response_event [:fishjam_web, :response]

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    metrics_ip = Application.fetch_env!(:fishjam, :metrics_ip)
    metrics_port = Application.fetch_env!(:fishjam, :metrics_port)

    Logger.info(
      "Starting prometheus metrics endpoint at: http://#{:inet.ntoa(metrics_ip)}:#{metrics_port}"
    )

    metrics_opts = [
      metrics: metrics(&last_value/2),
      port: metrics_port,
      plug_cowboy_opts: [ip: metrics_ip]
    ]

    children = [{TelemetryMetricsPrometheus, metrics_opts}]
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
    ] ++
      [
        # Fishjam Metrics

        # FIXME: At the moment, the traffic metrics track:
        #   - Most HTTP traffic (Fishjam API, HLS)
        #   - ICE events (WebRTC)
        #
        # which means they don't count:
        #   - WebSocket traffic
        #   - RTP events (RTSP components don't use ICE)
        #   - HTTP traffic related to metrics (not handled by Phoenix)

        metric_type.("fishjam.rpc.call.success.duration.seconds",
          event_name: [:fishjam, :rpc_client, :call, :success],
          measurement: :duration,
          unit: {:native, :second}
        ),
        metric_type.("fishjam.rpc.call.fail.duration.seconds",
          event_name: [:fishjam, :rpc_client, :call, :fail],
          measurement: :duration,
          unit: {:native, :second}
        ),
        metric_type.("fishjam.rpc.multicall.success.duration.seconds",
          event_name: [:fishjam, :rpc_client, :multicall, :success],
          measurement: :duration,
          unit: {:native, :second}
        ),
        metric_type.("fishjam.rpc.multicall.fail.duration.seconds",
          event_name: [:fishjam, :rpc_client, :multicall, :fail],
          measurement: :duration,
          unit: {:native, :second}
        ),
        sum("fishjam.traffic.ingress.webrtc.total.bytes",
          event_name: @ice_received_event,
          description: "Total WebRTC traffic received (bytes)"
        ),
        sum("fishjam.traffic.egress.webrtc.total.bytes",
          event_name: @ice_sent_event,
          description: "Total WebRTC traffic sent (bytes)"
        ),
        sum("fishjam.traffic.ingress.http.total.bytes",
          event_name: @http_request_event,
          description: "Total HTTP traffic received (bytes)"
        ),
        sum("fishjam.traffic.egress.http.total.bytes",
          event_name: @http_response_event,
          description: "Total HTTP traffic sent (bytes)"
        ),
        last_value("fishjam.rooms",
          description: "Number of rooms currently present in Fishjam"
        ),

        # FIXME: Prometheus warns about using labels to store dimensions with high cardinality,
        # such as UUIDs. For more information refer here: https://prometheus.io/docs/practices/naming/#labels
        last_value("fishjam.room.peers",
          tags: [:room_id],
          description: "Number of peers currently present in a given room"
        ),
        sum("fishjam.room.peer_time.total.seconds",
          event_name: [:fishjam, :room],
          measurement: :peer_time,
          tags: [:room_id],
          description: "Total peer time accumulated for a given room (seconds)"
        ),
        sum("fishjam.room.duration.seconds",
          event_name: [:fishjam, :room],
          measurement: :duration,
          tags: [:room_id],
          description: "Duration of a given room (seconds)"
        ),
        sum("fishjam.room.peer_connects.total",
          event_name: [:fishjam, :room],
          measurement: :peer_connects,
          tags: [:room_id],
          description:
            "Number of PeerConnected events emitted during the lifetime of a given room"
        ),
        sum("fishjam.room.peer_disconnects.total",
          event_name: [:fishjam, :room],
          measurement: :peer_disconnects,
          tags: [:room_id],
          description:
            "Number of PeerDisconnected events emitted during the lifetime of a given room"
        ),
        sum("fishjam.room.peer_crashes.total",
          event_name: [:fishjam, :room],
          measurement: :peer_crashes,
          tags: [:room_id],
          description: "Number of PeerCrashed events emitted during the lifetime of a given room"
        )
      ]
  end

  def default_webrtc_metrics() do
    :telemetry.execute(@ice_sent_event, %{bytes: 0})
    :telemetry.execute(@ice_received_event, %{bytes: 0})
  end
end
