defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.

  """

  use Bunch.Access
  use GenServer
  alias Jellyfish.Peer
  alias Jellyfish.Component

  @enforce_keys [
    :id,
    :config
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
  """
  @type t :: %__MODULE__{
          id: id,
          config: %{max_peers: max_peers()},
          components: %{},
          peers: %{Peer.id() => Peer.t()}
        }

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(max_peers) do
    # {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    # Engine.register(pid, self())
    # Process.monitor(pid)

    state = new(max_peers)

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_peer, peer_type}, _from, state) do
    if Enum.count(state.peers) == state.config.max_peers do
      {:reply, {:error, :reached_peers_limit}, state}
    else
      peer = Peer.new(peer_type)
      state = put_in(state, [:peers, peer.id], peer)
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
    %__MODULE__{
      id: UUID.uuid4(),
      config: %{max_peers: max_peers}
    }
  end
end
