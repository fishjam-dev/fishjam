defmodule Jellyfish.ResourceManager do
  @moduledoc """
  Module responsible for deleting outdated resources.
  Right now it only removes outdated resources created by recording component.
  """

  use GenServer, restart: :permanent

  require Logger

  alias Jellyfish.Component.Recording
  alias Jellyfish.RoomService

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

    base_path = Recording.get_base_path()
    dir_result = File.mkdir_p(base_path)

    case dir_result do
      {:error, reason} ->
        Logger.error("Can't create directory at #{base_path} with reason: #{reason}")

      :ok ->
        nil
    end

    schedule_free_resources(opts.interval)

    {:ok, opts}
  end

  @impl true
  def handle_info(:free_resources, state) do
    base_path = Recording.get_base_path()
    current_time = System.system_time(:second)

    rooms_list = File.ls!(base_path)

    recordings_list =
      rooms_list
      |> Enum.map(fn room ->
        room_path = Path.join(base_path, room)

        room_path
        |> File.ls!()
        |> Enum.map(fn recording -> {room, Path.join(room_path, recording)} end)
      end)
      |> Enum.concat()

    Enum.each(
      recordings_list,
      &remove_recording_if_obsolete(current_time, state.recording_timeout, &1)
    )

    Enum.each(rooms_list, &remove_room_if_obsolete(&1, base_path))

    schedule_free_resources(state.interval)

    {:noreply, state}
  end

  defp schedule_free_resources(interval),
    do: Process.send_after(self(), :free_resources, :timer.seconds(interval))

  defp remove_recording_if_obsolete(current_time, recording_timeout, {room, recording_path}) do
    with {:error, :room_not_found} <- RoomService.find_room(room) do
      case File.ls!(recording_path) do
        [] ->
          File.rm_rf!(recording_path)

        files ->
          # select the most recently modified file
          %{mtime: mtime} =
            files
            |> Enum.map(fn file ->
              recording_path |> Path.join(file) |> File.lstat!(time: :posix)
            end)
            |> Enum.sort_by(fn stats -> stats.mtime end, :desc)
            |> List.first()

          should_remove_recording?(current_time, mtime, recording_timeout) &&
            File.rm_rf!(recording_path)
      end
    end
  end

  defp remove_room_if_obsolete(room_id, base_path) do
    state_of_room = RoomService.find_room(room_id)
    room_path = Path.join(base_path, room_id)
    content = File.ls!(room_path)

    if should_remove_room?(content, state_of_room), do: File.rmdir!(room_path)
  end

  defp should_remove_room?([], {:error, :room_not_found}), do: true
  defp should_remove_room?(_content, _state_of_room), do: false

  defp should_remove_recording?(current_time, mtime, recording_timeout),
    do: current_time - mtime > recording_timeout
end
