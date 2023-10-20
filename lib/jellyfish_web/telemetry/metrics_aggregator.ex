defmodule JellyfishWeb.Telemetry.MetricsAggregator do
  @moduledoc false

  use GenServer

  # in seconds
  @metric_forwarding_interval 10

  @ice_received_event [Membrane.ICE, :ice, :payload, :received]
  @ice_sent_event [Membrane.ICE, :ice, :payload, :sent]
  @http_request_event [:jellyfish_web, :request]
  @http_response_event [:jellyfish_web, :response]

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec handle_event(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          %{ets_table: :ets.table()}
        ) :: :ok | {:error, atom()}
  def handle_event(name, measurements, metadata, config)

  def handle_event(@ice_received_event, %{bytes: bytes}, _metadata, %{ets_table: ets_table}) do
    :ets.update_counter(ets_table, :ingress_delta_webrtc, bytes, {:ingress_delta_webrtc, 0})
    :ok
  end

  def handle_event(@ice_sent_event, %{bytes: bytes}, _metadata, %{ets_table: ets_table}) do
    :ets.update_counter(ets_table, :egress_delta_webrtc, bytes, {:egress_delta_webrtc, 0})
    :ok
  end

  def handle_event(@http_request_event, %{bytes: bytes}, _metadata, %{ets_table: ets_table}) do
    :ets.update_counter(ets_table, :ingress_delta_http, bytes, {:ingress_delta_http, 0})
    :ok
  end

  def handle_event(@http_response_event, %{bytes: bytes}, _metadata, %{ets_table: ets_table}) do
    :ets.update_counter(ets_table, :egress_delta_http, bytes, {:egress_delta_http, 0})
    :ok
  end

  def handle_event(_name, _measurements, _metadata, _config), do: {:error, :unknown_event}

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics() do
    import Telemetry.Metrics

    [
      # FIXME: At the moment, the traffic metrics track:
      #   - Most HTTP traffic (Jellyfish API, HLS)
      #   - ICE events (WebRTC)
      #
      # which means they don't count:
      #   - WebSocket traffic
      #   - RTP events (RTSP components don't use ICE)
      #   - HTTP traffic related to metrics (not handled by Phoenix)
      sum("jellyfish.traffic.ingress.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_total,
        description: "Total traffic received (bytes)"
      ),
      last_value("jellyfish.traffic.ingress.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_throughput,
        description: "Current throughput for received traffic (bytes/second)"
      ),
      sum("jellyfish.traffic.egress.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_egress_total,
        description: "Total traffic sent (bytes)"
      ),
      last_value("jellyfish.traffic.egress.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_egress_throughput,
        description: "Current throughput for sent traffic (bytes/second)"
      ),
      sum("jellyfish.traffic.ingress.webrtc.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_total_webrtc,
        description: "Total WebRTC traffic received (bytes)"
      ),
      last_value("jellyfish.traffic.ingress.webrtc.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_throughput_webrtc,
        description: "Current throughput for received WebRTC traffic (bytes/second)"
      ),
      sum("jellyfish.traffic.egress.webrtc.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_egress_total_webrtc,
        description: "Total WebRTC traffic sent (bytes)"
      ),
      last_value("jellyfish.traffic.egress.webrtc.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_egress_throughput_webrtc,
        description: "Current throughput for sent WebRTC traffic (bytes/second)"
      ),
      sum("jellyfish.traffic.ingress.http.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_total_http,
        description: "Total HTTP traffic received (bytes)"
      ),
      last_value("jellyfish.traffic.ingress.http.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_throughput_http,
        description: "Current throughput for received HTTP traffic (bytes/second)"
      ),
      sum("jellyfish.traffic.egress.http.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_egress_total_http,
        description: "Total HTTP traffic sent (bytes)"
      ),
      last_value("jellyfish.traffic.egress.http.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_egress_throughput_http,
        description: "Current throughput for sent HTTP traffic (bytes/second)"
      ),
      last_value("jellyfish.rooms",
        description: "Amount of rooms currently present in Jellyfish"
      ),

      # FIXME: Prometheus warns about using labels to store dimensions with high cardinality,
      # such as UUIDs. For more information refer here: https://prometheus.io/docs/practices/naming/#labels
      last_value("jellyfish.room.peers",
        tags: [:room_id],
        description: "Amount of peers currently present in a given room"
      ),
      sum("jellyfish.room.peer_time.total.seconds",
        event_name: [:jellyfish, :room],
        measurement: :peer_time_total,
        tags: [:room_id],
        description: "Total peer time accumulated for a given room (seconds)"
      )
    ]
  end

  @impl true
  def init(_args) do
    ets_table = :ets.new(:measurements, [:public, :set, {:write_concurrency, true}])

    :telemetry.attach_many(
      __MODULE__,
      [@ice_received_event, @ice_sent_event, @http_request_event, @http_response_event],
      &__MODULE__.handle_event/4,
      %{ets_table: ets_table}
    )

    Process.send_after(self(), :forward_metrics, @metric_forwarding_interval * 1000)

    {:ok, %{ets_table: ets_table}}
  end

  @impl true
  def handle_info(:forward_metrics, %{ets_table: ets_table} = state) do
    rooms = Jellyfish.RoomService.list_rooms()

    [ingress_delta_webrtc, egress_delta_webrtc, ingress_delta_http, egress_delta_http] =
      :ets.tab2list(ets_table)
      |> Enum.flat_map(fn {key, _val} -> :ets.take(ets_table, key) end)
      |> then(fn kwl ->
        Enum.map(
          [:ingress_delta_webrtc, :egress_delta_webrtc, :ingress_delta_http, :egress_delta_http],
          &Keyword.get(kwl, &1, 0)
        )
      end)

    ingress_delta = ingress_delta_webrtc + ingress_delta_http
    egress_delta = egress_delta_webrtc + egress_delta_http

    :telemetry.execute(
      [:jellyfish],
      %{
        traffic_ingress_total: ingress_delta,
        traffic_ingress_total_webrtc: ingress_delta_webrtc,
        traffic_ingress_total_http: ingress_delta_http,
        traffic_ingress_throughput: rate(ingress_delta),
        traffic_ingress_throughput_webrtc: rate(ingress_delta_webrtc),
        traffic_ingress_throughput_http: rate(ingress_delta_http),
        traffic_egress_total: egress_delta,
        traffic_egress_total_webrtc: egress_delta_webrtc,
        traffic_egress_total_http: egress_delta_http,
        traffic_egress_throughput: rate(egress_delta),
        traffic_egress_throughput_webrtc: rate(egress_delta_webrtc),
        traffic_egress_throughput_http: rate(egress_delta_http),
        rooms: Enum.count(rooms)
      }
    )

    for room <- rooms do
      peer_count = room.peers |> Map.keys() |> Enum.count()

      :telemetry.execute(
        [:jellyfish, :room],
        %{
          peers: peer_count,
          peer_time_total: peer_count * @metric_forwarding_interval
        },
        %{room_id: room.id}
      )
    end

    Process.send_after(self(), :forward_metrics, @metric_forwarding_interval * 1000)

    {:noreply, state}
  end

  defp rate(amount), do: div(amount, @metric_forwarding_interval)
end
