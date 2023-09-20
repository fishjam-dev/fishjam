defmodule Jellyfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    scrape_interval = Application.fetch_env!(:jellyfish, :metrics_scrape_interval)
    dist_config = Application.fetch_env!(:jellyfish, :dist_config)

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
        {Registry, keys: :unique, name: Jellyfish.RoomRegistry},
        {Registry, keys: :unique, name: Jellyfish.RequestHandlerRegistry},
        # Start the Telemetry supervisor (must be started after Jellyfish.RoomRegistry)
        JellyfishWeb.Telemetry,
        {Task.Supervisor, name: Jellyfish.TaskSupervisor}
      ] ++
        if dist_config[:enabled] do
          config_distribution(dist_config)
        else
          []
        end

    :ets.new(:rooms_to_tables, [:public, :set, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jellyfish.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JellyfishWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp config_distribution(dist_config) do
    ensure_epmd_started!()

    # Release always starts in a distributed mode
    # so we have to start a node only in development.
    # See env.sh.eex for more information.
    unless Node.alive?() do
      case Node.start(dist_config[:node_name]) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          raise "Couldn't start Jellyfish node, reason: #{inspect(reason)}"
      end

      Node.set_cookie(dist_config[:cookie])
    end

    topologies = [
      epmd_cluster: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: dist_config[:nodes]]
      ]
    ]

    [{Cluster.Supervisor, [topologies, [name: Jellyfish.ClusterSupervisor]]}]
  end

  defp ensure_epmd_started!() do
    case System.cmd("epmd", ["-daemon"]) do
      {_, 0} ->
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
