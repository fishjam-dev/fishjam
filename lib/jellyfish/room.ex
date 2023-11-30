defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.
  """

  use Bunch.Access
  use GenServer

  require Logger

  alias Jellyfish.Component
  alias Jellyfish.Component.{File, HLS, RTSP}
  alias Jellyfish.Event
  alias Jellyfish.Peer

  alias Membrane.ICE.TURNManager
  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Track

  alias Membrane.RTC.Engine.Message.{
    EndpointAdded,
    EndpointCrashed,
    EndpointMessage,
    EndpointRemoved,
    TrackAdded,
    TrackRemoved
  }

  @enforce_keys [
    :id,
    :config,
    :engine_pid,
    :network_options
  ]
  defstruct @enforce_keys ++ [components: %{}, peers: %{}]

  @type id :: String.t()
  @type max_peers :: non_neg_integer() | nil
  @type video_codec :: :h264 | :vp8 | nil

  @typedoc """
  This module contains:
  * `id` - room id
  * `config` - configuration of room. For example you can specify maximal number of peers
  * `components` - map of components
  * `peers` - map of peers
  * `engine` - pid of engine
  """
  @type t :: %__MODULE__{
          id: id(),
          config: %{
            max_peers: max_peers(),
            video_codec: video_codec(),
            simulcast?: boolean()
          },
          components: %{Component.id() => Component.t()},
          peers: %{Peer.id() => Peer.t()},
          engine_pid: pid(),
          network_options: map()
        }

  defguardp endpoint_exists?(state, endpoint_id)
            when is_map_key(state.components, endpoint_id) or is_map_key(state.peers, endpoint_id)

  def registry_id(room_id), do: {:via, Registry, {Jellyfish.RoomRegistry, room_id}}

  @spec start(max_peers(), video_codec()) :: {:ok, pid(), id()}
  def start(max_peers, video_codec) do
    id = UUID.uuid4()

    {:ok, pid} = GenServer.start(__MODULE__, [id, max_peers, video_codec], name: registry_id(id))

    {:ok, pid, id}
  end

  @spec get_state(id()) :: t() | nil
  def get_state(room_id) do
    registry_room_id = registry_id(room_id)

    try do
      GenServer.call(registry_room_id, :get_state)
    catch
      :exit, {:noproc, {GenServer, :call, [^registry_room_id, :get_state, _timeout]}} ->
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
          | {:error, :incompatible_codec | :reached_components_limit}
  def add_component(room_id, component_type, options \\ %{}) do
    GenServer.call(registry_id(room_id), {:add_component, component_type, options})
  end

  @spec remove_component(id(), Component.id()) :: :ok | {:error, :component_not_found}
  def remove_component(room_id, component_id) do
    GenServer.call(registry_id(room_id), {:remove_component, component_id})
  end

  @spec hls_subscribe(id(), [Track.id()]) ::
          :ok | {:error, term()}
  def hls_subscribe(room_id, tracks) do
    GenServer.call(registry_id(room_id), {:hls_subscribe, tracks})
  end

  @spec receive_media_event(id(), Peer.id(), String.t()) :: :ok
  def receive_media_event(room_id, peer_id, event) do
    GenServer.cast(registry_id(room_id), {:media_event, peer_id, event})
  end

  @impl true
  def init([id, max_peers, video_codec]) do
    state = new(id, max_peers, video_codec)
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
      if Enum.count(state.peers) == state.config.max_peers do
        {{:error, :reached_peers_limit}, state}
      else
        options =
          Map.merge(
            %{
              engine_pid: state.engine_pid,
              network_options: state.network_options,
              video_codec: state.config.video_codec,
              room_id: state.id
            },
            options
          )

        with {:ok, peer} <- Peer.new(peer_type, options) do
          state = put_in(state, [:peers, peer.id], peer)

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
      case Map.fetch(state.peers, peer_id) do
        {:ok, %{status: :disconnected} = peer} ->
          Process.monitor(socket_pid)

          peer = %{peer | status: :connected, socket_pid: socket_pid}
          state = put_in(state, [:peers, peer_id], peer)

          :ok = Engine.add_endpoint(state.engine_pid, peer.engine_endpoint, id: peer_id)

          Logger.info("Peer #{inspect(peer_id)} connected")

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
      case Map.fetch(state.peers, peer_id) do
        {:ok, peer} -> {:ok, peer.status}
        :error -> {:error, :peer_not_found}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:remove_peer, peer_id}, _from, state) do
    {reply, state} =
      if Map.has_key?(state.peers, peer_id) do
        {peer, state} = pop_in(state, [:peers, peer_id])
        :ok = Engine.remove_endpoint(state.engine_pid, peer_id)

        if is_pid(peer.socket_pid),
          do: send(peer.socket_pid, {:stop_connection, :peer_removed})

        Logger.info("Removed peer #{inspect(peer_id)} from room #{inspect(state.id)}")
        Event.broadcast_server_notification({:peer_disconnected, state.id, peer_id})

        {:ok, state}
      else
        {{:error, :peer_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:add_component, component_type, options}, _from, state) do
    options =
      Map.merge(
        %{engine_pid: state.engine_pid, room_id: state.id},
        options
      )

    component_options = Map.delete(options, "s3")

    with :ok <- check_component_allowed(component_type, state),
         {:ok, component} <- Component.new(component_type, component_options) do
      state = put_in(state, [:components, component.id], component)

      if component_type == HLS do
        on_hls_startup(state.id, component.properties)
        spawn_hls_manager(options)
      end

      :ok = Engine.add_endpoint(state.engine_pid, component.engine_endpoint, id: component.id)

      Logger.info("Added component #{inspect(component.id)}")

      {:reply, {:ok, component}, state}
    else
      {:error, :incompatible_codec} ->
        Logger.warning("Unable to add component: incompatible codec")
        {:reply, {:error, :incompatible_codec}, state}

      {:error, :reached_components_limit} ->
        Logger.warning("Unable to add component: reached components limit")
        {:reply, {:error, :reached_components_limit}, state}

      {:error, reason} ->
        Logger.warning("Unable to add component: #{inspect(reason)}")
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:remove_component, component_id}, _from, state) do
    {reply, state} =
      if Map.has_key?(state.components, component_id) do
        {component, state} = pop_in(state, [:components, component_id])
        :ok = Engine.remove_endpoint(state.engine_pid, component_id)

        Logger.info("Removed component #{inspect(component_id)}")

        if component.type == HLS, do: on_hls_removal(state.id, component.properties)

        {:ok, state}
      else
        {{:error, :component_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:hls_subscribe, tracks}, _from, state) do
    hls_component = hls_component(state)

    reply =
      case validate_hls_subscription(hls_component) do
        :ok ->
          Engine.message_endpoint(state.engine_pid, hls_component.id, {:subscribe, tracks})

        {:error, _reason} = error ->
          error
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:get_num_forwarded_tracks, _from, state) do
    forwarded_tracks = Engine.get_num_forwarded_tracks(state.engine_pid)
    {:reply, forwarded_tracks, state}
  end

  @impl true
  def handle_cast({:media_event, peer_id, event}, state) do
    Engine.message_endpoint(state.engine_pid, peer_id, {:media_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointMessage{endpoint_id: to, message: {:media_event, data}}, state) do
    with {:ok, peer} <- Map.fetch(state.peers, to),
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
  def handle_info(%EndpointCrashed{endpoint_id: endpoint_id}, state) do
    Logger.error("RTC Engine endpoint #{inspect(endpoint_id)} crashed")

    if Map.has_key?(state.peers, endpoint_id) do
      Event.broadcast_server_notification({:peer_crashed, state.id, endpoint_id})

      peer = Map.fetch!(state.peers, endpoint_id)

      if peer.socket_pid != nil do
        send(peer.socket_pid, {:stop_connection, :endpoint_crashed})
      end
    else
      Event.broadcast_server_notification({:component_crashed, state.id, endpoint_id})

      component = Map.get(state.components, endpoint_id)
      if component.type == HLS, do: on_hls_removal(state.id, component.properties)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      case Enum.find(state.peers, fn {_id, peer} -> peer.socket_pid == pid end) do
        nil ->
          state

        {peer_id, peer} ->
          :ok = Engine.remove_endpoint(state.engine_pid, peer_id)
          Event.broadcast_server_notification({:peer_disconnected, state.id, peer_id})
          peer = %{peer | status: :disconnected, socket_pid: nil}
          put_in(state, [:peers, peer_id], peer)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:playlist_playable, :audio, _playlist_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:playlist_playable, :video, _playlist_id}, state) do
    endpoint_id =
      Enum.find_value(state.components, fn {id, %{type: type}} ->
        if type == HLS, do: id
      end)

    Event.broadcast_server_notification({:hls_playable, state.id, endpoint_id})

    state =
      update_in(state, [:components, endpoint_id, :properties], &Map.put(&1, :playable, true))

    {:noreply, state}
  end

  @impl true
  def handle_info(%EndpointMessage{endpoint_id: endpoint_id, message: :tracks_added}, state) do
    if state.components[endpoint_id].type == File do
      Logger.debug("Received track ready from file component")
      Engine.Endpoint.File.start_sending(state.engine_pid, endpoint_id)
    end

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
  def handle_info(
        %EndpointAdded{endpoint_id: endpoint_id},
        state
      )
      when endpoint_exists?(state, endpoint_id) do
    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackAdded{} = track_info, state) do
    Logger.info("Endpoint #{track_info.endpoint_id} added track #{inspect(track_info)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(%TrackRemoved{} = track_info, state) do
    Logger.info("Endpoint #{track_info.endpoint_id} removed track #{inspect(track_info)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    Logger.warning("Received unexpected info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{engine_pid: engine_pid} = state) do
    Engine.terminate(engine_pid, asynchronous?: true, timeout: 10_000)

    hls_component = hls_component(state)
    unless is_nil(hls_component), do: on_hls_removal(state.id, hls_component.properties)

    :ok
  end

  defp new(id, max_peers, video_codec) do
    rtc_engine_options = [
      id: id
    ]

    {:ok, pid} = Engine.start_link(rtc_engine_options, [])
    Engine.register(pid, self())

    webrtc_config = Application.fetch_env!(:jellyfish, :webrtc_config)

    turn_options =
      if webrtc_config[:webrtc_used] do
        turn_ip = webrtc_config[:turn_listen_ip]
        turn_mock_ip = webrtc_config[:turn_ip]

        [
          ip: turn_ip,
          mock_ip: turn_mock_ip,
          ports_range: webrtc_config[:turn_port_range]
        ]
      else
        []
      end

    tcp_turn_port = webrtc_config[:turn_tcp_port]

    if webrtc_config[:webrtc_used] and tcp_turn_port != nil do
      TURNManager.ensure_tcp_turn_launched(turn_options, port: tcp_turn_port)
    end

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers, video_codec: video_codec},
      engine_pid: pid,
      network_options: [turn_options: turn_options]
    }
  end

  defp hls_component(%{components: components}),
    do:
      Enum.find_value(components, fn {_id, component} ->
        if component.type == HLS, do: component
      end)

  defp on_hls_startup(room_id, %{low_latency: low_latency, persistent: persistent}) do
    room_id
    |> HLS.output_dir(persistent: persistent)
    |> then(&HLS.EtsHelper.add_hls_folder_path(room_id, &1))

    if low_latency, do: spawn_request_handler(room_id)
  end

  defp spawn_request_handler(room_id),
    do: HLS.RequestHandler.start(room_id)

  defp on_hls_removal(room_id, %{low_latency: low_latency}) do
    HLS.EtsHelper.delete_hls_folder_path(room_id)

    if low_latency, do: remove_request_handler(room_id)
  end

  defp remove_request_handler(room_id),
    do: HLS.RequestHandler.stop(room_id)

  defp check_component_allowed(HLS, %{
         config: %{video_codec: video_codec},
         components: components
       }) do
    cond do
      video_codec != :h264 ->
        {:error, :incompatible_codec}

      hls_component_already_present?(components) ->
        {:error, :reached_components_limit}

      true ->
        :ok
    end
  end

  defp check_component_allowed(RTSP, %{config: %{video_codec: video_codec}}) do
    # Right now, RTSP component can only publish H264, so there's no point adding it
    # to a room which enforces another video codec, e.g. VP8
    if video_codec in [:h264, nil],
      do: :ok,
      else: {:error, :incompatible_codec}
  end

  defp check_component_allowed(_component_type, _state), do: :ok

  defp hls_component_already_present?(components),
    do: components |> Map.values() |> Enum.any?(&(&1.type == HLS))

  defp spawn_hls_manager(%{engine_pid: engine_pid, room_id: room_id} = options) do
    {:ok, hls_dir} = HLS.EtsHelper.get_hls_folder_path(room_id)
    {:ok, valid_opts} = HLS.serialize_options(options)

    {:ok, _pid} = HLS.Manager.start(room_id, engine_pid, hls_dir, valid_opts)
  end

  defp validate_hls_subscription(nil), do: {:error, :hls_component_not_exists}

  defp validate_hls_subscription(%{metadata: %{subscribe_mode: :auto}}),
    do: {:error, :invalid_subscribe_mode}

  defp validate_hls_subscription(%{metadata: %{subscribe_mode: :manual}}), do: :ok
end
