defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.
  """

  use Bunch.Access
  use GenServer

  require Logger

  alias Jellyfish.Component
  alias Jellyfish.Peer
  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Message

  @enforce_keys [
    :id,
    :config,
    :engine_pid,
    :network_options
  ]
  defstruct @enforce_keys ++ [components: %{}, peers: %{}]

  @type id :: String.t()
  @type max_peers :: non_neg_integer() | nil

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
          config: %{max_peers: max_peers(), simulcast?: boolean()},
          components: %{Component.id() => Component.t()},
          peers: %{Peer.id() => Peer.t()},
          engine_pid: pid(),
          network_options: map()
        }

  @is_prod Mix.env() == :prod

  @spec start(max_peers()) :: {:ok, pid(), id()}
  def start(max_peers) do
    id = UUID.uuid4()
    {:ok, pid} = GenServer.start(__MODULE__, [id, max_peers], name: registry_id(id))
    {:ok, pid, id}
  end

  @spec get_state(id()) :: t() | nil
  def get_state(room_id) do
    room_id = registry_id(room_id)

    try do
      GenServer.call(room_id, :state)
    catch
      :exit, {:noproc, {GenServer, :call, [^room_id, :state, _timeout]}} ->
        Logger.warn(
          "Cannot get state of #{inspect(room_id)}, the room's process doesn't exist anymore"
        )

        nil
    end
  end

  @spec add_peer(id(), Peer.peer()) :: {:ok, Peer.t()} | {:error, :reached_peers_limit}
  def add_peer(room_id, peer_type) do
    GenServer.call(registry_id(room_id), {:add_peer, peer_type})
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

  @spec add_component(id(), Component.component(), map() | nil) :: {:ok, Component.t()}
  def add_component(room_id, component_type, options) do
    GenServer.call(registry_id(room_id), {:add_component, component_type, options})
  end

  @spec remove_component(id(), Component.id()) :: :ok | {:error, :component_not_found}
  def remove_component(room_id, component_id) do
    GenServer.call(registry_id(room_id), {:remove_component, component_id})
  end

  @impl true
  def init([id, max_peers]) do
    state = new(id, max_peers)
    Logger.metadata(room_id: id)
    Logger.info("Initialize room")

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_peer, peer_type}, _from, state) do
    {reply, state} =
      if Enum.count(state.peers) == state.config.max_peers do
        {{:error, :reached_peers_limit}, state}
      else
        options = %{engine_pid: state.engine_pid, network_options: state.network_options}
        peer = Peer.new(peer_type, options)
        state = put_in(state, [:peers, peer.id], peer)

        Logger.info("Added peer #{inspect(peer.id)}")

        {{:ok, peer}, state}
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

          :ok = Engine.add_endpoint(state.engine_pid, peer.engine_endpoint, peer_id: peer_id)

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
        if(is_nil(options), do: %{}, else: options)
      )

    component = Component.new(component_type, options)
    state = put_in(state, [:components, component.id], component)

    :ok =
      Engine.add_endpoint(state.engine_pid, component.engine_endpoint, endpoint_id: component.id)

    Logger.info("Added component #{inspect(component.id)}")

    {:reply, {:ok, component}, state}
  end

  @impl true
  def handle_call({:remove_component, component_id}, _from, state) do
    {reply, state} =
      if Map.has_key?(state.components, component_id) do
        {_elem, state} = pop_in(state, [:components, component_id])
        :ok = Engine.remove_endpoint(state.engine_pid, component_id)

        Logger.info("Removed component #{inspect(component_id)}")

        {:ok, state}
      else
        {{:error, :component_not_found}, state}
      end

    {:reply, reply, state}
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

    with {:ok, peer} <- Map.fetch(state.peers, endpoint_id),
         socket_pid when is_pid(socket_pid) <- Map.get(peer, :socket_pid) do
      send(socket_pid, {:stop_connection, :endpoint_crashed})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, to, event}, state) do
    Engine.message_endpoint(state.engine_pid, to, {:media_event, event})
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

  defp new(id, max_peers) do
    rtc_engine_options = [
      id: id
    ]

    {:ok, pid} = Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    network_options =
      if Application.fetch_env!(:jellyfish, :webrtc_used) do
        turn_cert_file =
          case Application.fetch_env(:jellyfish, :integrated_turn_cert_pkey) do
            {:ok, val} -> val
            :error -> nil
          end

        turn_mock_ip = Application.fetch_env!(:jellyfish, :integrated_turn_ip)

        turn_ip = if @is_prod, do: {0, 0, 0, 0}, else: turn_mock_ip

        integrated_turn_options = [
          ip: turn_ip,
          mock_ip: turn_mock_ip,
          ports_range: Application.fetch_env!(:jellyfish, :integrated_turn_port_range),
          cert_file: turn_cert_file
        ]

        [
          integrated_turn_options: integrated_turn_options,
          integrated_turn_domain: Application.fetch_env!(:jellyfish, :integrated_turn_domain),
          dtls_pkey: Application.get_env(:jellyfish, :dtls_pkey),
          dtls_cert: Application.get_env(:jellyfish, :dtls_cert)
        ]
      else
        []
      end

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers},
      engine_pid: pid,
      network_options: network_options
    }
  end

  defp registry_id(room_id), do: {:via, Registry, {Jellyfish.RoomRegistry, room_id}}
end
