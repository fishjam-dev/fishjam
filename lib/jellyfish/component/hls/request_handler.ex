defmodule Jellyfish.Component.HLS.RequestHandler do
  @moduledoc false

  use GenServer
  use Bunch.Access

  alias Jellyfish.Component.HLS.EtsHelper
  alias Jellyfish.Room

  @enforce_keys [:room_id]
  defstruct @enforce_keys ++
              [
                manifest: %{waiting_pids: %{}, last_partial: nil},
                delta_manifest: %{waiting_pids: %{}, last_partial: nil}
              ]

  @type segment_sn :: non_neg_integer()
  @type partial_sn :: non_neg_integer()
  @type partial :: {segment_sn(), partial_sn()}
  @type manifest :: %{waiting_pids: %{partial() => [pid()]}, last_partial: partial() | nil}

  @type t :: %__MODULE__{
          room_id: Room.id(),
          manifest: manifest(),
          delta_manifest: manifest()
        }

  @hls_directory "jellyfish_output/hls_output"

  @doc """
  Handles requests: playlists (regular hls), master playlist, headers, regular segments
  """
  @spec handle_file_request(Room.id(), String.t()) :: {:ok, binary()} | {:error | String.t()}
  def handle_file_request(room_id, filename) do
    path = Path.join([@hls_directory, room_id, filename])
    File.read(path)
  end

  @spec handle_partial_request(Room.id(), String.t(), non_neg_integer()) ::
          {:ok, binary()} | {:error | String.t()}
  def handle_partial_request(room_id, filename, offset) do
    EtsHelper.get_partial(room_id, filename, offset)
  end

  @doc """
  Should be called only when ll-hls
  """
  @spec handle_manifest_request(Room.id(), String.t(), partial()) :: binary()
  def handle_manifest_request(room_id, filename, partial) do
    last_partial = EtsHelper.get_last_partial(room_id, filename)

    unless is_partial_ready(partial, last_partial) do
      wait_for_manifest_ready(room_id, partial, filename)
    end

    EtsHelper.get_manifest(room_id, filename)
  end

  @spec update_last_partial(Room.id(), partial(), :regular | :delta) :: :ok
  def update_last_partial(room_id, partial, type) do
    GenServer.cast(registry_id(room_id), {:update_last_partial, partial, type})
  end

  def start(%{room_id: room_id} = config) do
    GenServer.start(__MODULE__, config, name: registry_id(room_id))
  end

  @impl true
  def init(%{room_id: room_id}), do: {:ok, %__MODULE__{room_id: room_id}}

  @impl true
  def handle_cast({:update_last_partial, last_partial, type}, state) do
    manifest_type = if type == :regular, do: :manifest, else: :delta_manifest

    {waiting_pids, manifest} =
      state
      |> Map.get(manifest_type)
      |> Map.put(:last_partial, last_partial)
      |> pop_in([:waiting_pids, last_partial])

    send_partial_ready(waiting_pids)

    state = Map.put(state, manifest_type, manifest)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:is_partial_ready, partial, filename, from}, state) do
    manifest_type =
      if String.contains?(filename, "_delta.m3u8"), do: :delta_manifest, else: :manifest

    manifest = Map.get(state, manifest_type)

    manifest =
      if is_partial_ready(partial, manifest.last_partial) do
        send(from, :manifest_ready)
        manifest
      else
        waiting_pids =
          Map.update(manifest.waiting_pids, partial, [from], fn pids_list ->
            [from | pids_list]
          end)

        %{manifest | waiting_pids: waiting_pids}
      end

    state = Map.put(state, manifest_type, manifest)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{room_id: room_id}) do
    EtsHelper.remove_room(room_id)
  end

  defp wait_for_manifest_ready(room_id, partial, filename) do
    GenServer.cast(registry_id(room_id), {:is_partial_ready, partial, filename, self()})

    receive do
      :manifest_ready ->
        :ok
    end
  end

  defp registry_id(room_id), do: {:via, Registry, {Jellyfish.RequestHandlerRegistry, room_id}}

  defp send_partial_ready(nil), do: nil

  defp send_partial_ready(waiting_pids) do
    Enum.each(waiting_pids, fn pid -> send(pid, :manifest_ready) end)
  end

  defp is_partial_ready(_partial, nil) do
    false
  end

  defp is_partial_ready(partial, last_partial),
    do: partial_to_integer(last_partial) >= partial_to_integer(partial)

  defp partial_to_integer({segment_sn, partial_sn}), do: segment_sn * 100 + partial_sn
end
