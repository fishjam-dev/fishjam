defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.
  """

  use Bunch.Access
  use GenServer
  alias Jellyfish.Peer
  alias Jellyfish.Component
  alias Membrane.RTC.Engine

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
          id: id,
          config: %{max_peers: max_peers(), simulcast?: boolean()},
          components: %{Component.id() => Component.t()},
          peers: %{Peer.id() => Peer.t()},
          engine_pid: pid(),
          network_options: map()
        }

  @mix_env Mix.env()

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(max_peers) do
    state = new(max_peers)

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    active_endpoints =
      state.engine_pid
      |> Engine.get_endpoints()
      |> Enum.map(& &1.id)
      |> MapSet.new()

    # Small redundancy here, map values also contain component/peer id
    peers =
      state.peers
      |> Enum.filter(fn {id, _component} -> MapSet.member?(active_endpoints, id) end)
      |> Map.new()

    components =
      state.components
      |> Enum.filter(fn {id, _component} -> MapSet.member?(active_endpoints, id) end)
      |> Map.new()

    {:reply, %{id: state.id, peers: peers, components: components, config: state.config}, state}
  end

  @impl true
  def handle_call({:add_peer, peer_type}, _from, state) do
    if Enum.count(state.peers) == state.config.max_peers do
      {:reply, {:error, :reached_peers_limit}, state}
    else
      options = %{engine_pid: state.engine_pid, network_options: state.network_options}
      peer = Peer.create_peer(peer_type, options)

      state = put_in(state, [:peers, peer.id], peer)

      :ok = Engine.add_endpoint(state.engine_pid, peer.engine_endpoint, endpoint_id: peer.id)

      {:reply, peer, state}
    end
  end

  @impl true
  def handle_call({:remove_peer, peer_id}, _from, state) do
    {result, state} =
      if Map.has_key?(state.peers, peer_id) do
        {_elem, state} = pop_in(state, [:peers, peer_id])
        :ok = Engine.remove_endpoint(state.engine_pid, peer_id)
        {:ok, state}
      else
        {:error, state}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:add_component, component_type, options}, _from, state) do
    component =
      Component.create_component(component_type, options, %{
        engine_pid: state.engine_pid,
        room_id: state.id
      })

    state = put_in(state, [:components, component.id], component)

    :ok =
      Engine.add_endpoint(state.engine_pid, component.engine_endpoint, endpoint_id: component.id)

    {:reply, component, state}
  end

  @impl true
  def handle_call({:remove_component, component_id}, _from, state) do
    {result, state} =
      if Map.has_key?(state.components, component_id) do
        {_elem, state} = pop_in(state, [:components, component_id])
        :ok = Engine.remove_endpoint(state.engine_pid, component_id)
        {:ok, state}
      else
        {:error, state}
      end

    {:reply, result, state}
  end

  @spec get_state(room_pid :: pid()) :: t()
  def get_state(room_pid) do
    GenServer.call(room_pid, :state)
  end

  @spec add_peer(room_pid :: pid(), peer_type :: Peer.peer_type()) :: Peer.t() | {:error, any()}
  def add_peer(room_pid, peer_type) do
    GenServer.call(room_pid, {:add_peer, peer_type})
  end

  @spec remove_peer(room_id :: pid(), peer_id: Peer.id()) :: :ok | :error
  def remove_peer(room_id, peer_id) do
    GenServer.call(room_id, {:remove_peer, peer_id})
  end

  @spec add_component(
          room_pid :: pid(),
          component_type :: Component.component_type(),
          options :: any()
        ) :: Component.t()
  def add_component(room_pid, component_type, options) do
    GenServer.call(room_pid, {:add_component, component_type, options})
  end

  @spec remove_component(room_pid :: pid(), component_id :: String.t()) :: :ok | :error
  def remove_component(room_pid, component_id) do
    GenServer.call(room_pid, {:remove_component, component_id})
  end

  defp new(max_peers) do
    id = UUID.uuid4()

    rtc_engine_options = [
      id: id
    ]

    {:ok, pid} = Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    turn_cert_file =
      case Application.fetch_env(:jellyfish, :integrated_turn_cert_pkey) do
        {:ok, val} -> val
        :error -> nil
      end

    turn_mock_ip = Application.fetch_env!(:jellyfish, :integrated_turn_ip)

    # turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip
    turn_ip = turn_mock_ip

    integrated_turn_options = [
      ip: turn_ip,
      mock_ip: turn_mock_ip,
      ports_range: Application.fetch_env!(:jellyfish, :integrated_turn_port_range),
      cert_file: turn_cert_file
    ]

    network_options = [
      integrated_turn_options: integrated_turn_options,
      integrated_turn_domain: Application.fetch_env!(:jellyfish, :integrated_turn_domain),
      dtls_pkey: Application.get_env(:jellyfish, :dtls_pkey),
      dtls_cert: Application.get_env(:jellyfish, :dtls_cert)
    ]

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers},
      engine_pid: pid,
      network_options: network_options
    }
  end
end
