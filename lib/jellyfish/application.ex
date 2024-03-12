defmodule Jellyfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    scrape_interval = Application.fetch_env!(:jellyfish, :webrtc_metrics_scrape_interval)
    dist_config = Application.fetch_env!(:jellyfish, :dist_config)
    webrtc_config = Application.fetch_env!(:jellyfish, :webrtc_config)
    git_commit = Application.get_env(:jellyfish, :git_commit)

    Logger.info("Starting Jellyfish v#{Jellyfish.version()} (#{git_commit})")
    Logger.info("Distribution config: #{inspect(Keyword.delete(dist_config, :cookie))}")
    Logger.info("WebRTC config: #{inspect(webrtc_config)}")

    children =
      [
        {Phoenix.PubSub, name: Jellyfish.PubSub},
        {Membrane.TelemetryMetrics.Reporter,
         [
           metrics: Membrane.RTC.Engine.Endpoint.WebRTC.Metrics.metrics(),
           name: JellyfishMetricsReporter
         ]},
        {Jellyfish.MetricsScraper, scrape_interval},
        JellyfishWeb.Endpoint,
        # Start the RoomService
        Jellyfish.RoomService,
        Jellyfish.WebhookNotifier,
        {Registry, keys: :unique, name: Jellyfish.RoomRegistry},
        {Registry, keys: :unique, name: Jellyfish.RequestHandlerRegistry},
        # Start the Telemetry supervisor (must be started after Jellyfish.RoomRegistry)
        JellyfishWeb.Telemetry,
        {Task.Supervisor, name: Jellyfish.TaskSupervisor},
        {DynamicSupervisor, name: Jellyfish.HLS.ManagerSupervisor, strategy: :one_for_one}
      ] ++
        if dist_config[:enabled] do
          config_distribution(dist_config)
        else
          []
        end

    :ets.new(:rooms_to_tables, [:public, :set, :named_table])
    :ets.new(:rooms_to_folder_paths, [:public, :set, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jellyfish.Supervisor]

    Application.put_env(:jellyfish, :start_time, System.monotonic_time(:second))

    result = Supervisor.start_link(children, opts)

    # If we do not set a default value for WebRTC metrics,
    # the metrics will be sent from the moment the first peer joins a room.
    JellyfishWeb.Telemetry.default_webrtc_metrics()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JellyfishWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp config_distribution(dist_config) do
    :ok = ensure_epmd_started!()

    # When running JF not in a cluster and using
    # mix release, it starts in the distributed mode
    # automatically
    unless Node.alive?() do
      case Node.start(dist_config[:node_name], dist_config[:mode]) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          raise "Couldn't start Jellyfish node, reason: #{inspect(reason)}"
      end

      Node.set_cookie(dist_config[:cookie])
    end

    topologies = [
      cluster: [
        strategy: dist_config[:strategy],
        config: dist_config[:strategy_config]
      ]
    ]

    [{Cluster.Supervisor, [topologies, [name: Jellyfish.ClusterSupervisor]]}]
  end

  defp ensure_epmd_started!() do
    case System.cmd("epmd", ["-daemon"]) do
      {_output, 0} ->
        :ok

      _other ->
        raise """
        Couldn't start epmd daemon.
        Epmd is required to run Jellyfish in a distributed mode.
        You can try to start it manually with:

          epmd -daemon

        and run Jellyfish again.
        """
    end
  end
end
