defmodule Jellyfish.ResourceManager do
  @moduledoc """
  Module responsible for deleting outdated resources.
  Right now it only removes outdated resources created by recording component.
  """

  use GenServer, restart: :temporary

  require Logger

  alias Jellyfish.Component.Recording

  @type seconds :: pos_integer()
  @type opts :: %{interval: seconds(), recording_timeout: seconds()}

  @spec start(opts()) :: {:ok, pid()} | {:error, term()}
  def start(opts), do: GenServer.start(__MODULE__, opts)

  @spec start_link(opts()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.debug("Initialize resource manager")

    schedule_free_resources(opts.interval)

    {:ok, opts}
  end

  @impl true
  def handle_info(:free_resources, state) do
    base_path = Recording.get_base_path()

    with {:ok, files} <- File.ls(base_path) do
      current_time = System.system_time(:second)

      files
      |> Enum.map(&Path.join(base_path, &1))
      |> Enum.each(&remove_recording_if_obsolete(current_time, state.recording_timeout, &1))
    else
      {:error, reason} ->
        Logger.error("Resource Manager: can't list recordings, reason: #{reason}")
    end

    schedule_free_resources(state.interval)

    {:noreply, state}
  end

  defp schedule_free_resources(interval),
    do: Process.send_after(self(), :free_resources, :timer.seconds(interval))

  defp remove_recording_if_obsolete(current_time, recording_timeout, recording_path) do
    file_stats =
      recording_path
      |> Path.join("report.json")
      |> File.lstat(time: :posix)

    with {:ok, %{mtime: mtime}} <- file_stats,
         true <- should_remove_file?(current_time, mtime, recording_timeout),
         {:ok, _files} <- File.rm_rf(recording_path) do
      :ok
    else
      false ->
        :ok

      {:error, reason, _files} ->
        Logger.error(
          "Resource Manager: can't remove recording - #{recording_path}. Reason: #{reason}"
        )

      {:error, reason} ->
        Logger.error("Resource Manager: can't read stats - #{recording_path}. Reason: #{reason}")
    end
  end

  defp should_remove_file?(current_time, mtime, recording_timeout),
    do: current_time - mtime > recording_timeout
end
