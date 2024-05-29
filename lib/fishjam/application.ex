defmodule Fishjam.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  # in seconds
  @resource_manager_opts %{interval: 600, recording_timeout: 3_600}

  # in milliseconds
  @epmd_timeout 5_000
  @epmd_pgrep_interval 500

  @impl true
  def start(_type, _args) do
    scrape_interval = Application.fetch_env!(:fishjam, :webrtc_metrics_scrape_interval)
    dist_config = Application.fetch_env!(:fishjam, :dist_config)
    webrtc_config = Application.fetch_env!(:fishjam, :webrtc_config)
    git_commit = Application.get_env(:fishjam, :git_commit)
    components_used = Application.get_env(:fishjam, :components_used)

    Logger.info("Starting Fishjam v#{Fishjam.version()} (#{git_commit})")
    Logger.info("Distribution config: #{inspect(Keyword.delete(dist_config, :cookie))}")
    Logger.info("WebRTC config: #{inspect(webrtc_config)}")
    Logger.info("Allowed components: #{inspect(components_used)}")

    children =
      [
        {Phoenix.PubSub, name: Fishjam.PubSub},
        {Membrane.TelemetryMetrics.Reporter,
         [
           metrics: Membrane.RTC.Engine.Endpoint.WebRTC.Metrics.metrics(),
           name: FishjamMetricsReporter
         ]},
        {Fishjam.MetricsScraper, scrape_interval},
        FishjamWeb.Endpoint,
        # Start the RoomService
        Fishjam.RoomService,
        # Start the ResourceManager, responsible for cleaning old recordings
        {Fishjam.ResourceManager, @resource_manager_opts},
        Fishjam.WebhookNotifier,
        {Registry, keys: :unique, name: Fishjam.RoomRegistry},
        {Registry, keys: :unique, name: Fishjam.RequestHandlerRegistry},
        # Start the Telemetry supervisor (must be started after Fishjam.RoomRegistry)
        FishjamWeb.Telemetry,
        {Task.Supervisor, name: Fishjam.TaskSupervisor},
        {DynamicSupervisor, name: Fishjam.HLS.ManagerSupervisor, strategy: :one_for_one}
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
    opts = [strategy: :one_for_one, name: Fishjam.Supervisor]

    Application.put_env(:fishjam, :start_time, System.monotonic_time(:second))

    result = Supervisor.start_link(children, opts)

    # If we do not set a default value for WebRTC metrics,
    # the metrics will be sent from the moment the first peer joins a room.
    FishjamWeb.Telemetry.default_webrtc_metrics()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FishjamWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp config_distribution(dist_config) do
    :ok = ensure_epmd_started!()

    # When running FJ not in a cluster and using
    # mix release, it starts in the distributed mode
    # automatically
    if Node.alive?() do
      Logger.info("""
      Not starting Fishjam node as it is already alive. \
      Node name: #{Node.self()}.\
      """)
    else
      case Node.start(dist_config[:node_name], dist_config[:mode]) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          raise "Couldn't start Fishjam node, reason: #{inspect(reason)}"
      end

      Node.set_cookie(dist_config[:cookie])
    end

    topologies = [
      cluster: [
        strategy: dist_config[:strategy],
        config: dist_config[:strategy_config]
      ]
    ]

    [{Cluster.Supervisor, [topologies, [name: Fishjam.ClusterSupervisor]]}]
  end

  defp ensure_epmd_started!() do
    try do
      {_output, 0} = System.cmd("epmd", ["-daemon"])
      # credo:disable-for-next-line
      :ok = Task.async(&ensure_epmd_running/0) |> Task.await(@epmd_timeout)

      :ok
    catch
      _exit_or_error, _e ->
        raise """
        Couldn't start epmd daemon.
        Epmd is required to run Fishjam in distributed mode.
        You can try to start it manually with:

          epmd -daemon

        and run Fishjam again.
        """
    end

    :ok
  end

  defp ensure_epmd_running() do
    with {:pgrep, {_output, 0}} <- {:pgrep, System.cmd("pgrep", ["epmd"])},
         {:epmd, {_output, 0}} <- {:epmd, System.cmd("epmd", ["-names"])} do
      :ok
    else
      {:pgrep, _other} ->
        Process.sleep(@epmd_pgrep_interval)
        ensure_epmd_running()

      {:epmd, _other} ->
        :error
    end
  end
end
