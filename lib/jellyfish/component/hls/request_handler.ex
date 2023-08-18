defmodule Jellyfish.Component.HLS.RequestHandler do
  @moduledoc false

  use GenServer
  use Bunch.Access

  alias Jellyfish.Component.HLS.EtsHelper
  alias Jellyfish.Room

  @enforce_keys [:room_id, :room_pid]
  defstruct @enforce_keys ++
              [
                manifest: %{waiting_pids: %{}, last_partial: nil},
                delta_manifest: %{waiting_pids: %{}, last_partial: nil}
              ]

  @type segment_sn :: non_neg_integer()
  @type partial_sn :: non_neg_integer()
  @type partial :: {segment_sn(), partial_sn()}
  @type status :: %{waiting_pids: %{partial() => [pid()]}, last_partial: partial() | nil}

  @type t :: %__MODULE__{
          room_id: Room.id(),
          room_pid: pid(),
          manifest: status(),
          delta_manifest: status()
        }

  @hls_directory "jellyfish_output/hls_output"

  ###
  ### HLS Controller API
  ###

  @doc """
  Handles requests: playlists (regular hls), master playlist, headers, regular segments
  """
  @spec handle_file_request(Room.id(), String.t()) :: {:ok, binary()} | {:error | String.t()}
  def handle_file_request(room_id, filename) do
    path = Path.join([@hls_directory, room_id, filename])
    File.read(path)
  end

  @doc """
  Handles ll-hls partial requests
  """
  @spec handle_partial_request(Room.id(), String.t(), non_neg_integer()) ::
          {:ok, binary()} | {:error | atom()}
  def handle_partial_request(room_id, filename, offset) do
    EtsHelper.get_partial(room_id, filename, offset)
  end

  @doc """
  Handles manifest requests with specific partial requested (ll-hls)
  """
  @spec handle_manifest_request(Room.id(), partial()) :: {:ok, binary()} | {:error, any()}
  def handle_manifest_request(room_id, partial) do
    {:ok, last_partial} = EtsHelper.get_recent_partial(room_id)

    unless is_partial_ready?(partial, last_partial) do
      wait_for_manifest_ready(room_id, partial)
    end

    EtsHelper.get_manifest(room_id)
  end

  @doc """
  Handles manifest requests with specific partial requested (ll-hls)
  """
  @spec handle_delta_manifest_request(Room.id(), partial()) :: {:ok, String.t()} | {:error, any()}
  def handle_delta_manifest_request(room_id, partial) do
    {:ok, last_partial} = EtsHelper.get_delta_recent_partial(room_id)

    unless is_partial_ready?(partial, last_partial) do
      wait_for_delta_manifest_ready(room_id, partial)
    end

    EtsHelper.get_delta_manifest(room_id)
  end

  ###
  ### STORAGE API
  ###

  @spec update_recent_partial(Room.id(), partial()) :: :ok
  def update_recent_partial(room_id, partial) do
    GenServer.cast(registry_id(room_id), {:update_recent_partial, partial})
  end

  @spec update_delta_recent_partial(Room.id(), partial()) :: :ok
  def update_delta_recent_partial(room_id, partial) do
    GenServer.cast(registry_id(room_id), {:update_delta_recent_partial, partial})
  end

  ###
  ### MANAGMENT API
  ###

  def start(%{room_id: room_id}) do
    GenServer.start(__MODULE__, %{room_id: room_id, room_pid: self()}, name: registry_id(room_id))
  end

  def stop(room_id) do
    GenServer.cast(registry_id(room_id), :shutdown)
  end

  @impl true
  def init(%{room_id: room_id, room_pid: room_pid}) do
    Process.monitor(room_pid)
    {:ok, %__MODULE__{room_id: room_id, room_pid: room_pid}}
  end

  @impl true
  def handle_cast({:update_recent_partial, last_partial}, %{manifest: status} = state) do
    state = Map.put(state, :manifest, update_status(status, last_partial))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_delta_recent_partial, last_partial}, %{delta_manifest: status} = state) do
    state = Map.put(state, :delta_manifest, update_status(status, last_partial))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:is_partial_ready, partial, from}, %{manifest: status} = state) do
    status = handle_is_partial_ready(status, partial, from)
    state = Map.put(state, :manifest, status)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:is_delta_partial_ready, partial, from}, %{delta_manifest: status} = state) do
    status = handle_is_partial_ready(status, partial, from)
    state = Map.put(state, :delta_manifest, status)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:shutdown, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %{room_id: room_id}) do
    EtsHelper.remove_room(room_id)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{room_pid: pid} = state) do
    {:stop, :normal, state}
  end

  ###
  ### PRIVATE FUNCTIONS
  ###

  defp wait_for_manifest_ready(room_id, partial) do
    GenServer.cast(registry_id(room_id), {:is_partial_ready, partial, self()})

    receive do
      :manifest_ready ->
        :ok
    end
  end

  defp wait_for_delta_manifest_ready(room_id, partial) do
    GenServer.cast(registry_id(room_id), {:is_delta_partial_ready, partial, self()})

    receive do
      :manifest_ready ->
        :ok
    end
  end

  defp update_status(status, last_partial) do
    {waiting_pids, status} =
      status
      |> Map.put(:last_partial, last_partial)
      |> pop_in([:waiting_pids, last_partial])

    send_partial_ready(waiting_pids)
    status
  end

  defp handle_is_partial_ready(status, partial, from) do
    if is_partial_ready?(partial, status.last_partial) do
      send(from, :manifest_ready)
      status
    else
      waiting_pids =
        Map.update(status.waiting_pids, partial, [from], fn pids_list ->
          [from | pids_list]
        end)

      %{status | waiting_pids: waiting_pids}
    end
  end

  defp registry_id(room_id), do: {:via, Registry, {Jellyfish.RequestHandlerRegistry, room_id}}

  defp send_partial_ready(nil), do: nil

  defp send_partial_ready(waiting_pids) do
    Enum.each(waiting_pids, fn pid -> send(pid, :manifest_ready) end)
  end

  defp is_partial_ready?(_partial, nil) do
    false
  end

  defp is_partial_ready?(partial, last_partial),
    do: partial_to_integer(last_partial) >= partial_to_integer(partial)

  defp partial_to_integer({segment_sn, partial_sn}), do: segment_sn * 100 + partial_sn
end
