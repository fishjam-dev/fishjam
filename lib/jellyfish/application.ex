defmodule Jellyfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    scrape_interval = Application.fetch_env!(:jellyfish, :metrics_scrape_interval)

    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
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
      # Start the Telemetry supervisor (must be started after Jellyfish.RoomRegistry)
      JellyfishWeb.Telemetry
    ]

    children =
      if topologies == [] do
        children
      else
        [{Cluster.Supervisor, [topologies, [name: Jellyfish.ClusterSupervisor]]} | children]
      end

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
end
