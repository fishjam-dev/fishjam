defmodule JellyfishWeb.Telemetry.MetricsAggregator do
  @moduledoc false

  use GenServer

  # in seconds
  @metric_forwarding_interval 10

  @ice_received_event [Membrane.ICE, :ice, :payload, :received]
  @ice_sent_event [Membrane.ICE, :ice, :payload, :sent]

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
    :ets.update_counter(ets_table, :ingress_delta, bytes, {:ingress_delta, 0})
    :ok
  end

  def handle_event(@ice_sent_event, %{bytes: bytes}, _metadata, %{ets_table: ets_table}) do
    :ets.update_counter(ets_table, :egress_delta, bytes, {:egress_delta, 0})
    :ok
  end

  def handle_event(_name, _measurements, _metadata, _config), do: {:error, :unknown_event}

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics() do
    import Telemetry.Metrics

    [
      # FIXME: The traffic metrics work only with ICE events (emitted only by WebRTC components)
      # which means they don't count the traffic from/to RTSP and HLS components
      sum("jellyfish.traffic.ingress.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_total
      ),
      last_value("jellyfish.traffic.ingress.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_ingress_throughput
      ),
      sum("jellyfish.traffic.egress.total.bytes",
        event_name: [:jellyfish],
        measurement: :traffic_egress_total
      ),
      last_value("jellyfish.traffic.egress.throughput.bytes_per_second",
        event_name: [:jellyfish],
        measurement: :traffic_egress_throughput
      ),
      last_value("jellyfish.rooms"),

      # FIXME: Prometheus warns about using labels to store dimensions with high cardinality,
      # such as UUIDs. For more information refer here: https://prometheus.io/docs/practices/naming/#labels
      last_value("jellyfish.room.peers",
        tags: [:room_id]
      ),
      sum("jellyfish.room.peer_time.total.seconds",
        event_name: [:jellyfish, :room],
        measurement: :peer_time_total,
        tags: [:room_id]
      )
    ]
  end

  @impl true
  def init(_args) do
    ets_table = :ets.new(:measurements, [:public, :set, {:write_concurrency, true}])

    :telemetry.attach_many(
      __MODULE__,
      [@ice_received_event, @ice_sent_event],
      &__MODULE__.handle_event/4,
      %{ets_table: ets_table}
    )

    Process.send_after(self(), :forward_metrics, @metric_forwarding_interval * 1000)

    {:ok, %{ets_table: ets_table}}
  end

  @impl true
  def handle_info(:forward_metrics, %{ets_table: ets_table} = state) do
    rooms = Jellyfish.RoomService.list_rooms()

    [ingress_delta, egress_delta] =
      :ets.tab2list(ets_table)
      |> Enum.flat_map(fn {key, _val} -> :ets.take(ets_table, key) end)
      |> then(fn kwl -> Enum.map([:ingress_delta, :egress_delta], &Keyword.get(kwl, &1, 0)) end)

    :telemetry.execute(
      [:jellyfish],
      %{
        traffic_ingress_total: ingress_delta,
        traffic_ingress_throughput: div(ingress_delta, @metric_forwarding_interval),
        traffic_egress_total: egress_delta,
        traffic_egress_throughput: div(egress_delta, @metric_forwarding_interval),
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
end
