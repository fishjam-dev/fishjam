defmodule Jellyfish.Room do
  @moduledoc """
  Module representing room.

  """

  use Bunch.Access
  use GenServer
  alias Jellyfish.Peer

  @enforce_keys [
    :id,
    :config
  ]
  defstruct @enforce_keys ++ [producers: [], consumers: [], peers: %{}]

  @type id :: String.t()
  @type max_peers :: integer() | nil

  @typedoc """
  This module contains:
  * `id` - room id
  * `config` - configuration of room. For example you can specify maximal number of peers
  * `producers` - list of producers
  * `consumers` - list of consumers
  * `peers` - list of peers
  """
  @type t :: %__MODULE__{
          id: id,
          config: %{max_peers: max_peers()},
          producers: [],
          consumers: [],
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
    {:ok, new(max_peers)}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_peer, peer_type}, _from, state) do
    peer = Peer.new(peer_type)
    state = put_in(state, [:peers, peer.id], peer)
    {:reply, peer, state}
  end

  @spec get_state(room_pid :: pid()) :: t()
  def get_state(room_pid) do
    GenServer.call(room_pid, :state)
  end

  @spec add_peer(room_pid :: pid(), peer_type :: Peer.peer_type()) :: Peer.t()
  def add_peer(room_pid, peer_type) do
    GenServer.call(room_pid, {:add_peer, peer_type})
  end

  defp new(max_peers) do
    %__MODULE__{
      id: UUID.uuid4(),
      config: %{max_peers: max_peers}
    }
  end
end
