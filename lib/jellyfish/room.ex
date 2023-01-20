defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.

  """

  use Bunch.Access
  use GenServer
  alias Jellyfish.Peer
  alias Jellyfish.Component
  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig

  @enforce_keys [
    :id,
    :config,
    :engine_pid,
    :network_options
  ]
  defstruct @enforce_keys ++ [components: %{}, peers: %{}]

  @type id :: String.t()
  @type max_peers :: integer() | nil

  @typedoc """
  This module contains:
  * `id` - room id
  * `config` - configuration of room. For example you can specify maximal number of peers
  * `components` - list of components
  * `peers` - list of peers
  * `engine` - pid of engine
  """
  @type t :: %__MODULE__{
          id: id,
          config: %{max_peers: max_peers(), simulcast?: boolean()},
          components: %{},
          peers: %{Peer.id() => Peer.t()},
          engine_pid: pid(),
          network_options: %{}
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
    {:reply, state, state}
  end

  def handle_call({:add_peer, peer_type}, _from, state) do
    peers_number = Enum.count(state.peers)

    case peer_type do
      _any_peer_type when peers_number == state.config.max_peers ->
        {:reply, {:error, :reached_peers_limit}, state}

      :webrtc ->
        {peer, state} = add_webrtc(peer_type, state)
        {:reply, peer, state}
    end
  end

  def handle_call({:add_component, component_type}, _from, state) do
    component = Component.new(component_type)
    state = put_in(state, [:components, component.id], component)
    {:reply, component, state}
  end

  def handle_call({:remove_component, component_id}, _from, state) do
    {result, state} =
      if Map.has_key?(state.components, component_id) do
        {_elem, state} = pop_in(state, [:components, component_id])
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

  @spec add_component(room_pid :: pid(), component_type :: Component.component_type()) ::
          Component.t()
  def add_component(room_pid, component_type) do
    GenServer.call(room_pid, {:add_component, component_type})
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
    turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip

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

  defp add_webrtc(peer_type, state) do
    peer = Peer.new(peer_type)
    state = put_in(state, [:peers, peer.id], peer)

    simulcast? = true

    handshake_opts =
      if state.network_options[:dtls_pkey] &&
           state.network_options[:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: state.network_options[:dtls_pkey],
          cert: state.network_options[:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    webrtc_extensions =
      if simulcast? do
        [Mid, Rid, TWCC]
      else
        [TWCC]
      end

    endpoint = %WebRTC{
      rtc_engine: state.engine_pid,
      ice_name: peer.id,
      owner: self(),
      integrated_turn_options: state.network_options[:integrated_turn_options],
      integrated_turn_domain: state.network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id],
      trace_context: nil,
      webrtc_extensions: webrtc_extensions,
      simulcast_config: %SimulcastConfig{
        enabled: simulcast?,
        initial_target_variant: fn _track -> :medium end
      }
    }

    :ok = Engine.add_endpoint(state.engine_pid, endpoint, endpoint_id: peer.id)

    {peer, state}
  end
end
