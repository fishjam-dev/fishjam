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

  @spec handle_event(term(), map(), map(), map()) :: :ok
  def handle_event(name, measurements, metadata, config),
    do: GenServer.cast(config.handler, {:event, name, measurements, metadata})

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics() do
    import Telemetry.Metrics

    [
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
    :telemetry.attach_many(
      __MODULE__,
      [@ice_received_event, @ice_sent_event],
      &__MODULE__.handle_event/4,
      %{handler: self()}
    )

    Process.send_after(self(), :forward_metrics, @metric_forwarding_interval * 1000)

    state = %{
      ingress_delta: 0,
      egress_delta: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:event, @ice_received_event, %{bytes: bytes}, _metadata}, state),
    do: {:noreply, Map.update(state, :ingress_delta, 0, &(&1 + bytes))}

  def handle_cast({:event, @ice_sent_event, %{bytes: bytes}, _metadata}, state),
    do: {:noreply, Map.update(state, :egress_delta, 0, &(&1 + bytes))}

  def handle_cast(_msg, state), do: {:noreply, state}

  @impl true
  def handle_info(
        :forward_metrics,
        %{ingress_delta: ingress_delta, egress_delta: egress_delta} = state
      ) do
    rooms = Jellyfish.RoomService.list_rooms()

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

    {:noreply, Map.keys(state) |> Map.new(&{&1, 0})}
  end
end
