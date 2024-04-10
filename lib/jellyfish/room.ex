defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.
  """

  use Bunch.Access
  use GenServer

  import Jellyfish.Room.State

  require Logger

  alias Jellyfish.Component
  alias Jellyfish.Component.{HLS, Recording, SIP}
  alias Jellyfish.Event
  alias Jellyfish.Peer
  alias Jellyfish.Room.{Config, State}

  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Endpoint

  alias Membrane.RTC.Engine.Message.{
    EndpointAdded,
    EndpointCrashed,
    EndpointMessage,
    EndpointMetadataUpdated,
    EndpointRemoved,
    TrackAdded,
    TrackMetadataUpdated,
    TrackRemoved
  }

  @type id :: String.t()
  @type t :: State.t()

  def registry_id(room_id), do: {:via, Registry, {Jellyfish.RoomRegistry, room_id}}

  @spec start(Config.t()) :: {:ok, pid(), id()}
  def start(%Config{room_id: id} = config) do
    with {:ok, pid} <- GenServer.start(__MODULE__, [id, config], name: registry_id(id)) do
      {:ok, pid, id}
    else
      {:error, {:already_started, _pid}} ->
        {:error, :room_already_exists}
    end
  end

  @spec get_state(id()) :: State.t() | nil
  def get_state(room_id) do
    registry_room_id = registry_id(room_id)

    try do
      GenServer.call(registry_room_id, :get_state)
    catch
      :exit, {reason, {GenServer, :call, [^registry_room_id, :get_state, _timeout]}}
      when reason in [:noproc, :normal] ->
        Logger.warning(
          "Cannot get state of #{inspect(room_id)}, the room's process doesn't exist anymore"
        )

        nil
    end
  end

  @spec get_num_forwarded_tracks(id()) :: integer()
  def get_num_forwarded_tracks(room_id) do
    GenServer.call(registry_id(room_id), :get_num_forwarded_tracks)
  end

  @spec add_peer(id(), Peer.peer(), map()) ::
          {:ok, Peer.t()} | :error | {:error, :reached_peers_limit}
  def add_peer(room_id, peer_type, options \\ %{}) do
    GenServer.call(registry_id(room_id), {:add_peer, peer_type, options})
  end

  @spec set_peer_connected(id(), Peer.id()) ::
          :ok | {:error, :peer_not_found | :peer_already_connected}
  def set_peer_connected(room_id, peer_id) do
    GenServer.call(registry_id(room_id), {:set_peer_connected, peer_id})
  end

  @spec get_peer_connection_status(id(), Peer.id()) ::
          {:ok, Peer.status()} | {:error, :peer_not_found}
  def get_peer_connection_status(room_id, peer_id) do
    GenServer.call(registry_id(room_id), {:get_peer_connection_status, peer_id})
  end

  @spec remove_peer(id(), Peer.id()) :: :ok | {:error, :peer_not_found}
  def remove_peer(room_id, peer_id) do
    GenServer.call(registry_id(room_id), {:remove_peer, peer_id})
  end

  @spec add_component(id(), Component.component(), map()) ::
          {:ok, Component.t()}
          | :error
          | {:error, :incompatible_codec | :reached_components_limit_hls}
  def add_component(room_id, component_type, options \\ %{}) do
    GenServer.call(registry_id(room_id), {:add_component, component_type, options})
  end

  @spec remove_component(id(), Component.id()) :: :ok | {:error, :component_not_found}
  def remove_component(room_id, component_id) do
    GenServer.call(registry_id(room_id), {:remove_component, component_id})
  end

  @spec subscribe(id(), Component.id(), [Peer.id() | Component.id()]) ::
          :ok | {:error, term()}
  def subscribe(room_id, component_id, origins) do
    GenServer.call(registry_id(room_id), {:subscribe, component_id, origins})
  end

  @spec dial(id(), Component.id(), String.t()) ::
          :ok | {:error, term()}
  def dial(room_id, component_id, phone_number) do
    GenServer.call(registry_id(room_id), {:dial, component_id, phone_number})
  end

  @spec end_call(id(), Component.id()) ::
          :ok | {:error, term()}
  def end_call(room_id, component_id) do
    GenServer.call(registry_id(room_id), {:end_call, component_id})
  end

  @spec receive_media_event(id(), Peer.id(), String.t()) :: :ok
  def receive_media_event(room_id, peer_id, event) do
    GenServer.cast(registry_id(room_id), {:media_event, peer_id, event})
  end

  @impl true
  def init([id, config]) do
    state = State.new(id, config)
    Logger.metadata(room_id: id)
    Logger.info("Initialize room")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_peer, peer_type, options}, _from, state) do
    {reply, state} =
      if State.reached_peers_limit?(state) do
        {{:error, :reached_peers_limit}, state}
      else
        options = State.generate_peer_options(state, options)

        with {:ok, peer} <- Peer.new(peer_type, options) do
          state = State.put_peer(state, peer)

          Logger.info("Added peer #{inspect(peer.id)}")

          {{:ok, peer}, state}
        else
          {:error, reason} ->
            Logger.warning("Unable to add peer: #{inspect(reason)}")
            {:error, state}
        end
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:set_peer_connected, peer_id}, {socket_pid, _tag}, state) do
    {reply, state} =
      case State.fetch_peer(state, peer_id) do
        {:ok, %{status: :disconnected} = peer} ->
          Process.monitor(socket_pid)

          peer = %{peer | status: :connected, socket_pid: socket_pid}
          state = put_in(state, [:peers, peer_id], peer)

          :ok =
            state
            |> State.engine_pid()
            |> Engine.add_endpoint(peer.engine_endpoint, id: peer_id)

          Logger.info("Peer #{inspect(peer_id)} connected")

          :telemetry.execute([:jellyfish, :room], %{peer_connects: 1}, %{room_id: State.id(state)})

          {:ok, state}

        {:ok, %{status: :connected}} ->
          {{:error, :peer_already_connected}, state}

        :error ->
          {{:error, :peer_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get_peer_connection_status, peer_id}, _from, state) do
    reply =
      case State.fetch_peer(state, peer_id) do
        {:ok, peer} -> {:ok, peer.status}
        :error -> {:error, :peer_not_found}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:remove_peer, peer_id}, _from, state) do
    {reply, state} =
      if peer_exists?(state, peer_id) do
        state = State.remove_peer(state, peer_id, :peer_removed)

        {:ok, state}
      else
        {{:error, :peer_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:add_component, component_type, options}, _from, state) do
    engine_pid = State.engine_pid(state)

    options =
      Map.merge(
        %{engine_pid: engine_pid, room_id: State.id(state)},
        options
      )

    with :ok <- check_component_allowed(component_type, state),
         {:ok, component} <- Component.new(component_type, options) do
      state = State.put_component(state, component)

      component_type.after_init(state, component, options)

      :ok = Engine.add_endpoint(engine_pid, component.engine_endpoint, id: component.id)

      Logger.info("Added component #{inspect(component.id)}")

      {:reply, {:ok, component}, state}
    else
      {:error, :incompatible_codec} ->
        Logger.warning("Unable to add component: incompatible codec")
        {:reply, {:error, :incompatible_codec}, state}

      {:error, :reached_components_limit} ->
        type = Component.to_string!(component_type)
        Logger.warning("Unable to add component: reached components limit #{type}")
        {:reply, {:error, {:reached_components_limit, type}}, state}

      {:error, :file_does_not_exist} ->
        Logger.warning("Unable to add component: file does not exist")
        {:reply, {:error, :file_does_not_exist}, state}

      {:error, :bad_parameter_framerate_for_audio} ->
        Logger.warning("Attempted to set framerate for audio component which is not supported.")

        {:reply, {:error, :bad_parameter_framerate_for_audio}, state}

      {:error, {:invalid_framerate, passed_framerate}} ->
        Logger.warning(
          "Invalid framerate value: #{passed_framerate}.  It has to be a positivie integer."
        )

        {:reply, {:error, :invalid_framerate}, state}

      {:error, :invalid_file_path} ->
        Logger.warning("Unable to add component: invalid file path")
        {:reply, {:error, :invalid_file_path}, state}

      {:error, :unsupported_file_type} ->
        Logger.warning("Unable to add component: unsupported file path")
        {:reply, {:error, :unsupported_file_type}, state}

      {:error, {:missing_parameter, name}} ->
        Logger.warning("Unable to add component: missing parameter #{inspect(name)}")
        {:reply, {:error, {:missing_parameter, name}}, state}

      {:error, :missing_s3_credentials} ->
        Logger.warning("Unable to add component: missing s3 credentials")
        {:reply, {:error, :missing_s3_credentials}, state}

      {:error, :overridding_credentials} ->
        Logger.warning("Unable to add component: tried to override s3 credentials")
        {:reply, {:error, :overridding_credentials}, state}

      {:error, :overridding_path_prefix} ->
        Logger.warning("Unable to add component: tried to override s3 path_prefix")
        {:reply, {:error, :overridding_path_prefix}, state}

      {:error, reason} ->
        Logger.warning("Unable to add component: #{inspect(reason)}")
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:remove_component, component_id}, _from, state) do
    {reply, state} =
      if component_exists?(state, component_id) do
        state = State.remove_component(state, component_id, :component_removed)
        {:ok, state}
      else
        {{:error, :component_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:subscribe, component_id, origins}, _from, state) do
    component = State.get_component_by_id(state, component_id)

    engine_pid = State.engine_pid(state)

    reply =
      case validate_subscription_mode(component) do
        :ok when component.type == HLS ->
          Endpoint.HLS.subscribe(engine_pid, component.id, origins)

        :ok when component.type == Recording ->
          Endpoint.Recording.subscribe(engine_pid, component.id, origins)

        :ok when component.type not in [HLS, Recording] ->
          {:error, :invalid_component_type}

        {:error, _reason} = error ->
          error
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:get_num_forwarded_tracks, _from, state) do
    forwarded_tracks =
      state
      |> State.engine_pid()
      |> Engine.get_num_forwarded_tracks()

    {:reply, forwarded_tracks, state}
  end

  @impl true
  def handle_call({:dial, component_id, phone_number}, _from, state) do
    case State.fetch_component(state, component_id) do
      {:ok, component} when component.type == SIP ->
        state
        |> State.engine_pid()
        |> Endpoint.SIP.dial(component_id, phone_number)

        {:reply, :ok, state}

      {:ok, _component} ->
        {:reply, {:error, :bad_component_type}, state}

      :error ->
        {:reply, {:error, :component_does_not_exist}, state}
    end
  end

  @impl true
  def handle_call({:end_call, component_id}, _from, state) do
    case State.fetch_component(state, component_id) do
      {:ok, component} when component.type == SIP ->
        state
        |> State.engine_pid()
        |> Endpoint.SIP.end_call(component_id)

        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :component_does_not_exist}, state}

      {:ok, _component} ->
        {:reply, {:error, :bad_component_type}, state}
    end
  end

  @impl true
  def handle_cast({:media_event, peer_id, event}, state) do
    state
    |> State.engine_pid()
    |> Engine.message_endpoint(peer_id, {:media_event, event})

    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointMessage{endpoint_id: to, message: {:media_event, data}}, state) do
    with {:ok, peer} <- State.fetch_peer(state, to),
         socket_pid when is_pid(socket_pid) <- Map.get(peer, :socket_pid) do
      send(socket_pid, {:media_event, data})
    else
      nil ->
        Logger.warning(
          "Received Media Event from RTC Engine to peer #{inspect(to)} without established signaling connection"
        )

      :error ->
        Logger.warning(
          "Received Media Event from RTC Engine to non existent peer (target id: #{inspect(to)})"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointCrashed{endpoint_id: endpoint_id, reason: reason}, state) do
    Logger.error("RTC Engine endpoint #{inspect(endpoint_id)} crashed: #{inspect(reason)}")

    state =
      if peer_exists?(state, endpoint_id) do
        State.remove_peer(state, endpoint_id, {:peer_crashed, parse_crash_reason(reason)})
      else
        State.remove_component(state, endpoint_id, :component_crashed)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      case State.find_peer_with_pid(state, pid) do
        nil ->
          state

        {peer_id, peer} ->
          room_id = State.id(state)

          :ok =
            state
            |> State.engine_pid()
            |> Engine.remove_endpoint(peer_id)

          Event.broadcast_server_notification({:peer_disconnected, room_id, peer_id})
          :telemetry.execute([:jellyfish, :room], %{peer_disconnects: 1}, %{room_id: room_id})

          peer.tracks
          |> Map.values()
          |> Enum.each(
            &Event.broadcast_server_notification(
              {:track_removed, room_id, {:peer_id, peer_id}, &1}
            )
          )

          peer = %{peer | status: :disconnected, socket_pid: nil, tracks: %{}}

          State.put_peer(state, peer)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:playlist_playable, :audio, _playlist_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:playlist_playable, :video, _playlist_id}, state) do
    endpoint_id = State.find_hls_component_id(state)

    Event.broadcast_server_notification({:hls_playable, State.id(state), endpoint_id})

    state =
      update_in(state, [:components, endpoint_id, :properties], &Map.put(&1, :playable, true))

    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointMessage{} = msg, state) do
    Logger.debug("Received msg from endpoint: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(
        %EndpointRemoved{endpoint_id: endpoint_id},
        state
      )
      when not endpoint_exists?(state, endpoint_id) do
    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointRemoved{endpoint_id: endpoint_id}, state)
      when peer_exists?(state, endpoint_id) do
    # The peer has been either removed, crashed or disconnected
    # The changes in state are applied in appropriate callbacks
    {:noreply, state}
  end

  def handle_info(%EndpointRemoved{endpoint_id: endpoint_id}, state)
      when component_exists?(state, endpoint_id) do
    state = State.remove_component(state, endpoint_id, :component_finished)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        %EndpointAdded{endpoint_id: endpoint_id},
        state
      )
      when endpoint_exists?(state, endpoint_id) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        %EndpointMetadataUpdated{endpoint_id: endpoint_id, endpoint_metadata: metadata},
        state
      )
      when peer_exists?(state, endpoint_id) do
    Logger.info("Peer #{endpoint_id} metadata updated: #{inspect(metadata)}")

    Event.broadcast_server_notification(
      {:peer_metadata_updated, State.id(state), endpoint_id, metadata}
    )

    state = put_in(state, [:peers, endpoint_id, :metadata], metadata)
    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointMetadataUpdated{}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackAdded{endpoint_id: endpoint_id} = track_info, state)
      when endpoint_exists?(state, endpoint_id) do
    state = State.put_track(state, track_info)

    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackAdded{endpoint_id: endpoint_id} = track_info, state) do
    Logger.error("Unknown endpoint #{endpoint_id} added track #{inspect(track_info)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackMetadataUpdated{endpoint_id: endpoint_id} = track_info, state)
      when endpoint_exists?(state, endpoint_id) do
    state = State.update_track(state, track_info)

    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackMetadataUpdated{endpoint_id: endpoint_id} = track_info, state) do
    Logger.error("Unknown endpoint #{endpoint_id} updated track #{inspect(track_info)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackRemoved{endpoint_id: endpoint_id} = track_info, state)
      when endpoint_exists?(state, endpoint_id) do
    state = State.remove_track(state, track_info)

    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackRemoved{endpoint_id: endpoint_id} = track_info, state) do
    Logger.error("Unknown endpoint #{endpoint_id} removed track #{inspect(track_info)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:peerless_purge, state) do
    if State.peerless_long_enough?(state) do
      Logger.info(
        "Removing room because it was peerless for #{State.peerless_purge_timeout(state)} seconds"
      )

      {:stop, :normal, state}
    else
      Logger.debug("Ignore peerless purge message")

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(info, state) do
    Logger.warning("Received unexpected info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{engine_pid: engine_pid} = state) do
    Engine.terminate(engine_pid, asynchronous?: true, timeout: 10_000)

    State.remove_all_endpoints(state)

    :ok
  end

  defp parse_crash_reason(
         {:membrane_child_crash, _child, {%RuntimeError{message: reason}, _stack}}
       ),
       do: reason

  defp parse_crash_reason(_reason), do: nil
end
