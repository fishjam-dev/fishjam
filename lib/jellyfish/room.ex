defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.
  """

  use Bunch.Access
  use GenServer

  require Logger

  alias Jellyfish.Component
  alias Jellyfish.Event
  alias Jellyfish.Peer
  alias Membrane.ICE.TURNManager
  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Endpoint.Remote
  alias Membrane.RTC.Engine.Message

  @enforce_keys [
    :id,
    :config,
    :engine_pid,
    :network_options
  ]
  defstruct @enforce_keys ++ [components: %{}, peers: %{}, nodes: %{}]

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
          network_options: map(),
          nodes: %{binary() => node()}
        }

  @spec start(max_peers(), video_codec(), id() | nil) :: {:ok, pid(), id()}
  def start(max_peers, video_codec, id \\ nil) do
    id = id || UUID.uuid4()

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
        Logger.warn(
          "Cannot get state of #{inspect(room_id)}, the room's process doesn't exist anymore"
        )

        nil
    end
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

  @spec receive_media_event(id(), Peer.id(), String.t()) :: :ok
  def receive_media_event(room_id, peer_id, event) do
    GenServer.cast(registry_id(room_id), {:media_event, peer_id, event})
  end

  @impl true
  def init([id, max_peers, video_codec]) do
    node = Node.self()
    state = new(id, max_peers, video_codec, node)
    Phoenix.PubSub.subscribe(Jellyfish.PubSub, id)
    Phoenix.PubSub.broadcast(Jellyfish.PubSub, id, {:room_created, node})
    Logger.metadata(room_id: id)
    Logger.info("Initialize room")

    {:ok, state}
  end

  @impl true
  def handle_info({:room_created, node}, %__MODULE__{id: id, nodes: nodes} = state) do
    cond do
      node != Node.self() ->
        Phoenix.PubSub.broadcast(Jellyfish.PubSub, id, {:room_exists, Node.self()})
        Logger.info("#{node} created multipart room (room_id=#{id})")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:room_exists, node}, %__MODULE__{nodes: nodes} = state) do
    if node != Node.self() do
      Logger.info("Room #{id} exists on node #{node}")

      endpoint_id = UUID.uuid4()

      Engine.add_endpoint(
        state.engine_pid,
        %Remote{rtc_engine: state.engine_pid, owner: self()},
        id: endpoint_id
      )

      {:noreply, put_in(state, [:nodes, endpoint_id], node)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(%Message.EndpointAdded{}, state), do: {:noreply, state}

  @impl true
  def handle_info(
        %Message.EndpointMessage{
          endpoint_id: endpoint_id,
          endpoint_type: Remote,
          message: {:link_proposal, %Remote.LinkProposal{} = link_proposal}
        },
        %__MODULE__{id: room_id} = state
      ) do
    case get_in(state, [:nodes, endpoint_id]) do
      nil ->
        Logger.warning("Wrong Remote Endpoint")

      node ->
        Phoenix.PubSub.direct_broadcast(
          node,
          Jellyfish.PubSub,
          room_id,
          {:create_remote_endpoint, link_proposal, Node.self()}
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:create_remote_endpoint, config, node},
        %__MODULE__{engine_pid: engine_pid} = state
      ) do
    endpoint_id = UUID.uuid4()

    Engine.add_endpoint(
      state.engine_pid,
      %Remote{rtc_engine: state.engine_pid, owner: self(), connection_setup: config},
      id: endpoint_id
    )

    {:noreply, put_in(state, [:nodes, endpoint_id], node)}
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
            Logger.warn("Unable to add peer: #{inspect(reason)}")
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

    with :ok <- check_component_allowed(component_type, state),
         {:ok, component} <- Component.new(component_type, options) do
      state = put_in(state, [:components, component.id], component)

      :ok = Engine.add_endpoint(state.engine_pid, component.engine_endpoint, id: component.id)

      Logger.info("Added component #{inspect(component.id)}")

      {:reply, {:ok, component}, state}
    else
      {:error, :incompatible_codec} ->
        Logger.warn("Unable to add component: incompatible codec")
        {:reply, {:error, :incompatible_codec}, state}

      {:error, :reached_components_limit} ->
        Logger.warn("Unable to add component: reached components limit")
        {:reply, {:error, :reached_components_limit}, state}

      {:error, reason} ->
        Logger.warn("Unable to add component: #{inspect(reason)}")
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

        if component.type == Component.HLS, do: remove_hls_processes(state.id)

        {:ok, state}
      else
        {{:error, :component_not_found}, state}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:media_event, peer_id, event}, state) do
    Engine.message_endpoint(state.engine_pid, peer_id, {:media_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.EndpointMessage{endpoint_id: to, message: {:media_event, data}}, state) do
    with {:ok, peer} <- Map.fetch(state.peers, to),
         socket_pid when is_pid(socket_pid) <- Map.get(peer, :socket_pid) do
      send(socket_pid, {:media_event, data})
    else
      nil ->
        Logger.warn(
          "Received Media Event from RTC Engine to peer #{inspect(to)} without established signaling connection"
        )

      :error ->
        Logger.warn(
          "Received Media Event from RTC Engine to non existent peer (target id: #{inspect(to)})"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.EndpointCrashed{endpoint_id: endpoint_id}, state) do
    Logger.error("RTC Engine endpoint #{inspect(endpoint_id)} crashed")

    if Map.has_key?(state.peers, endpoint_id) do
      Event.broadcast(:server_notification, {:peer_crashed, state.id, endpoint_id})

      peer = Map.fetch!(state.peers, endpoint_id)

      if peer.socket_pid != nil do
        send(peer.socket_pid, {:stop_connection, :endpoint_crashed})
      end
    else
      Event.broadcast(:server_notification, {:component_crashed, state.id, endpoint_id})

      %{type: type} = Map.get(state.components, endpoint_id)
      if type == Component.HLS, do: remove_hls_processes(state.id)
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
        if type == Component.HLS, do: id
      end)

    Event.broadcast(:server_notification, {:hls_playable, state.id, endpoint_id})

    state = update_in(state, [:components, endpoint_id], &Map.put(&1, :playable, true))
    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    Logger.warn("Received unexpected info: #{inspect(info)}")
    {:noreply, state}
  end

  defp new(id, max_peers, video_codec, node) do
    rtc_engine_options = [
      id: id
    ]

    {:ok, pid} = Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    integrated_turn_options =
      if Application.fetch_env!(:jellyfish, :webrtc_used) do
        turn_ip = Application.fetch_env!(:jellyfish, :integrated_turn_listen_ip)
        turn_mock_ip = Application.fetch_env!(:jellyfish, :integrated_turn_ip)

        [
          ip: turn_ip,
          mock_ip: turn_mock_ip,
          ports_range: Application.fetch_env!(:jellyfish, :integrated_turn_port_range)
        ]
      else
        []
      end

    tcp_turn_port = Application.fetch_env!(:jellyfish, :integrated_turn_tcp_port)

    if tcp_turn_port do
      TURNManager.ensure_tcp_turn_launched(integrated_turn_options, port: tcp_turn_port)
    end

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers, video_codec: video_codec},
      engine_pid: pid,
      network_options: [integrated_turn_options: integrated_turn_options],
      nodes: %{}
    }
  end

  defp remove_hls_processes(room_id), do: Component.HLS.RequestHandler.stop(room_id)

  defp registry_id(room_id), do: {:via, Registry, {Jellyfish.RoomRegistry, room_id}}

  defp check_component_allowed(Component.HLS, %{
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

  defp check_component_allowed(Component.RTSP, %{config: %{video_codec: video_codec}}) do
    # Right now, RTSP component can only publish H264, so there's no point adding it
    # to a room which enforces another video codec, e.g. VP8
    if video_codec in [:h264, nil],
      do: :ok,
      else: {:error, :incompatible_codec}
  end

  defp check_component_allowed(_component_type, _state), do: :ok

  defp hls_component_already_present?(components),
    do: components |> Map.values() |> Enum.any?(&(&1.type == Component.HLS))
end
