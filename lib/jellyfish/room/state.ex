defmodule Jellyfish.Room.State do
  @moduledoc false

  use Bunch.Access

  require Logger

  alias Jellyfish.{Component, Event, Peer, Room, Track}
  alias Jellyfish.Component.{HLS, Recording, RTSP}
  alias Jellyfish.Room.Config
  alias Membrane.ICE.TURNManager
  alias Membrane.RTC.Engine

  alias Membrane.RTC.Engine.Message.{
    TrackAdded,
    TrackMetadataUpdated,
    TrackRemoved
  }

  @enforce_keys [
    :id,
    :config,
    :engine_pid,
    :network_options
  ]
  defstruct @enforce_keys ++ [components: %{}, peers: %{}, last_peer_left: 0]

  @type reason_t :: any()
  @type endpoint_id :: Component.id() | Peer.id()

  @typedoc """
  This module contains:
  * `id` - room id
  * `config` - configuration of room. For example you can specify maximal number of peers
  * `components` - map of components
  * `peers` - map of peers
  * `engine` - pid of engine
  * `network_options` - network options
  * `last_peer_left` - arbitrary timestamp with latest occurence of the room becoming peerless
  """
  @type t :: %__MODULE__{
          id: Room.id(),
          config: Config.t(),
          components: %{Component.id() => Component.t()},
          peers: %{Peer.id() => Peer.t()},
          engine_pid: pid(),
          network_options: map(),
          last_peer_left: integer()
        }

  defguard peer_exists?(state, endpoint_id) when is_map_key(state.peers, endpoint_id)

  defguard component_exists?(state, endpoint_id) when is_map_key(state.components, endpoint_id)

  defguard endpoint_exists?(state, endpoint_id)
           when peer_exists?(state, endpoint_id) or component_exists?(state, endpoint_id)

  @spec new(id :: Room.id(), config :: Config.t()) :: t()
  def new(id, config) do
    rtc_engine_options = [
      id: id
    ]

    {:ok, pid} = Engine.start_link(rtc_engine_options, [])
    Engine.register(pid, self())

    webrtc_config = Application.fetch_env!(:jellyfish, :webrtc_config)

    turn_options =
      if webrtc_config[:webrtc_used?] do
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

    if webrtc_config[:webrtc_used?] and tcp_turn_port != nil do
      TURNManager.ensure_tcp_turn_launched(turn_options, port: tcp_turn_port)
    end

    state =
      %__MODULE__{
        id: id,
        config: config,
        engine_pid: pid,
        network_options: [turn_options: turn_options]
      }
      |> maybe_schedule_peerless_purge()

    state
  end

  @spec id(state :: t()) :: Room.id()
  def id(state), do: state.id

  @spec engine_pid(state :: t()) :: pid()
  def engine_pid(state), do: state.engine_pid

  @spec peerless_purge_timeout(state :: t()) :: Config.purge_timeout()
  def peerless_purge_timeout(state), do: state.config.peerless_purge_timeout

  @spec peerless_long_enough?(state :: t()) :: boolean()
  def peerless_long_enough?(%{config: config, peers: peers, last_peer_left: last_peer_left}) do
    if all_peers_disconnected?(peers) do
      Klotho.monotonic_time(:millisecond) >= last_peer_left + config.peerless_purge_timeout * 1000
    else
      false
    end
  end

  @spec peer_disconnected_long_enough?(state :: t(), peer :: Peer.t()) :: boolean()
  def peer_disconnected_long_enough?(_state, peer) when peer.status != :disconnected, do: false

  def peer_disconnected_long_enough?(state, peer) do
    remove_timestamp = peer.last_time_connected + state.config.peer_disconnected_timeout * 1000

    now = Klotho.monotonic_time(:millisecond)

    now >= remove_timestamp
  end

  @spec put_peer(state :: t(), peer :: Peer.t()) :: t()
  def put_peer(state, peer) do
    state
    |> put_in([:peers, peer.id], peer)
    |> maybe_schedule_peer_purge(peer)
    |> maybe_schedule_peerless_purge()
  end

  @spec put_component(state :: t(), component :: Component.t()) :: t()
  def put_component(state, component) do
    put_in(state, [:components, component.id], component)
  end

  @spec put_track(state :: t(), track_info :: TrackAdded.t()) :: t()
  def put_track(state, %TrackAdded{endpoint_id: endpoint_id} = track_info) do
    track = Track.from_track_message(track_info)
    endpoint_id_type = get_endpoint_id_type(state, endpoint_id)

    Logger.info("Track #{track.id} added, #{endpoint_id_type}: #{endpoint_id}")

    Event.broadcast_server_notification(
      {:track_added, state.id, {endpoint_id_type, endpoint_id}, track_info}
    )

    track = Track.from_track_message(track_info)

    endpoint_group = get_endpoint_group(state, endpoint_id)
    access_path = [endpoint_group, endpoint_id, :tracks, track.id]

    put_in(state, access_path, track)
  end

  @spec update_track(state :: t(), track_info :: TrackMetadataUpdated.t()) :: t()
  def update_track(state, %TrackMetadataUpdated{endpoint_id: endpoint_id} = track_info) do
    endpoint_group = get_endpoint_group(state, endpoint_id)
    access_path = [endpoint_group, endpoint_id, :tracks, track_info.track_id]

    update_in(state, access_path, fn
      %Track{} = track ->
        endpoint_id_type = get_endpoint_id_type(state, endpoint_id)
        updated_track = %Track{track | metadata: track_info.track_metadata}

        Logger.info(
          "Track #{updated_track.id}, #{endpoint_id_type}: #{endpoint_id} - metadata updated: #{inspect(updated_track.metadata)}"
        )

        Event.broadcast_server_notification(
          {:track_metadata_updated, state.id, {endpoint_id_type, endpoint_id}, updated_track}
        )

        updated_track
    end)
  end

  @spec remove_track(state :: t(), track_info :: TrackRemoved.t()) :: t()
  def remove_track(state, %TrackRemoved{endpoint_id: endpoint_id} = track_info) do
    endpoint_group = get_endpoint_group(state, endpoint_id)
    access_path = [endpoint_group, endpoint_id, :tracks, track_info.track_id]

    {track, state} = pop_in(state, access_path)

    endpoint_id_type = get_endpoint_id_type(state, endpoint_id)
    Logger.info("Track removed: #{track.id}, #{endpoint_id_type}: #{endpoint_id}")

    Event.broadcast_server_notification(
      {:track_removed, state.id, {endpoint_id_type, endpoint_id}, track}
    )

    state
  end

  @spec fetch_peer(state :: t(), peer_id :: Peer.id()) :: {:ok, Peer.t()} | :error
  def fetch_peer(state, peer_id), do: Map.fetch(state.peers, peer_id)

  @spec fetch_component(state :: t(), component_id :: Component.id()) ::
          {:ok, Component.t()} | :error
  def fetch_component(state, component_id), do: Map.fetch(state.components, component_id)

  @spec update_peer_metadata(state :: t(), peer_id :: Peer.id(), metadata :: any()) :: t()
  def update_peer_metadata(state, peer_id, metadata) do
    Event.broadcast_server_notification({:peer_metadata_updated, state.id, peer_id, metadata})

    put_in(state, [:peers, peer_id, :metadata], metadata)
  end

  @spec add_peer(state :: t(), peer :: Peer.t()) :: t()
  def add_peer(state, peer) do
    state = put_peer(state, peer)

    Logger.info("Added peer #{inspect(peer.id)}")
    Event.broadcast_server_notification({:peer_added, state.id, peer.id})

    state
  end

  @spec connect_peer(state :: t(), peer :: Peer.t(), socket_pid :: pid()) :: t()
  def connect_peer(state, peer, socket_pid) do
    peer = %{peer | status: :connected, socket_pid: socket_pid}

    state = put_peer(state, peer)

    :ok = Engine.add_endpoint(state.engine_pid, peer.engine_endpoint, id: peer.id)

    Logger.info("Peer #{inspect(peer.id)} connected")

    :telemetry.execute([:jellyfish, :room], %{peer_connects: 1}, %{room_id: state.id})

    state
  end

  @spec disconnect_peer(state :: t(), peer_ws_pid :: pid()) :: t()
  def disconnect_peer(state, peer_ws_pid) do
    case find_peer_with_pid(state, peer_ws_pid) do
      nil ->
        state

      {peer_id, peer} ->
        :ok = Engine.remove_endpoint(state.engine_pid, peer_id)

        Event.broadcast_server_notification({:peer_disconnected, state.id, peer_id})
        :telemetry.execute([:jellyfish, :room], %{peer_disconnects: 1}, %{room_id: state.id})

        peer.tracks
        |> Map.values()
        |> Enum.each(
          &Event.broadcast_server_notification(
            {:track_removed, state.id, {:peer_id, peer_id}, &1}
          )
        )

        peer = %{peer | status: :disconnected, socket_pid: nil, tracks: %{}}

        put_peer(state, peer)
    end
  end

  @spec remove_peer(state :: t(), peer_id :: Peer.id(), reason :: any()) :: t()
  def remove_peer(state, peer_id, :timeout) do
    {peer, state} = pop_in(state, [:peers, peer_id])

    Event.broadcast_server_notification({:peer_deleted, state.id, peer.id})

    maybe_schedule_peerless_purge(state)
  end

  def remove_peer(state, peer_id, reason) do
    {peer, state} = pop_in(state, [:peers, peer_id])
    :ok = Engine.remove_endpoint(state.engine_pid, peer_id)

    if is_pid(peer.socket_pid),
      do: send(peer.socket_pid, {:stop_connection, reason})

    peer.tracks
    |> Map.values()
    |> Enum.each(
      &Event.broadcast_server_notification({:track_removed, state.id, {:peer_id, peer_id}, &1})
    )

    Logger.info("Removed peer #{inspect(peer_id)} from room #{inspect(state.id)}")

    if peer.status == :connected and reason == :peer_removed do
      Event.broadcast_server_notification({:peer_disconnected, state.id, peer_id})
      :telemetry.execute([:jellyfish, :room], %{peer_disconnects: 1}, %{room_id: state.id})
    end

    case reason do
      {:peer_crashed, crash_reason} ->
        Event.broadcast_server_notification({:peer_crashed, state.id, peer_id, crash_reason})
        :telemetry.execute([:jellyfish, :room], %{peer_crashes: 1}, %{room_id: state.id})

      _other ->
        Event.broadcast_server_notification({:peer_deleted, state.id, peer.id})
    end

    maybe_schedule_peerless_purge(state)
  end

  @spec remove_component(state :: t(), component_id :: Component.id(), reason :: reason_t()) ::
          t()
  def remove_component(state, component_id, reason) do
    {component, state} = pop_in(state, [:components, component_id])
    :ok = Engine.remove_endpoint(state.engine_pid, component_id)

    component.tracks
    |> Map.values()
    |> Enum.each(
      &Event.broadcast_server_notification(
        {:track_removed, state.id, {:component_id, component_id}, &1}
      )
    )

    Logger.info("Removed component #{inspect(component_id)}: #{inspect(reason)}")

    component.type.on_remove(state, component)

    if reason == :component_crashed,
      do: Event.broadcast_server_notification({:component_crashed, state.id, component_id})

    state
  end

  @spec remove_all_endpoints(state :: t()) :: :ok
  def remove_all_endpoints(state) do
    state.peers
    |> Map.values()
    |> Enum.each(&remove_peer(state, &1.id, :room_stopped))

    state.components
    |> Map.values()
    |> Enum.each(&remove_component(state, &1.id, :room_stopped))
  end

  @spec find_peer_with_pid(state :: t(), pid :: pid()) :: {Peer.id(), Peer.t()} | nil
  defp find_peer_with_pid(state, pid),
    do: Enum.find(state.peers, fn {_id, peer} -> peer.socket_pid == pid end)

  @spec get_component_by_id(state :: t(), component_id :: Component.id()) :: Component.t() | nil
  def get_component_by_id(state, component_id) do
    Enum.find_value(state.components, fn {id, component} ->
      if id == component_id, do: component
    end)
  end

  @spec set_hls_playable(state :: t()) :: t()
  def set_hls_playable(state) do
    endpoint_id = find_hls_component_id(state)

    Event.broadcast_server_notification({:hls_playable, state.id, endpoint_id})

    update_in(state, [:components, endpoint_id, :properties], &Map.put(&1, :playable, true))
  end

  @spec find_hls_component_id(state :: t()) :: Component.t() | nil
  def find_hls_component_id(state),
    do:
      Enum.find_value(state.components, fn {id, %{type: type}} ->
        if type == HLS, do: id
      end)

  @spec reached_peers_limit?(state :: t()) :: boolean()
  def reached_peers_limit?(state), do: Enum.count(state.peers) == state.config.max_peers

  @spec generate_peer_options(state :: t(), override_options :: map()) :: map()
  def generate_peer_options(state, override_options) do
    Map.merge(
      %{
        engine_pid: state.engine_pid,
        network_options: state.network_options,
        video_codec: state.config.video_codec,
        room_id: state.id
      },
      override_options
    )
  end

  @spec check_peer_allowed(Peer.peer(), t()) ::
          :ok | {:error, :peer_disabled_globally | :reached_peers_limit}
  def check_peer_allowed(Peer.WebRTC, state) do
    cond do
      not Application.fetch_env!(:jellyfish, :webrtc_config)[:webrtc_used?] ->
        {:error, :peer_disabled_globally}

      Enum.count(state.peers) >= state.config.max_peers ->
        {:error, :reached_peers_limit}

      true ->
        :ok
    end
  end

  @spec check_component_allowed(Component.component(), t()) ::
          :ok
          | {:error,
             :component_disabled_globally | :incompatible_codec | :reached_components_limit}
  def check_component_allowed(type, state) do
    if type in Application.fetch_env!(:jellyfish, :components_used) do
      check_component_allowed_in_room(type, state)
    else
      {:error, :component_disabled_globally}
    end
  end

  @spec get_endpoint_id_type(state :: t(), endpoint_id :: endpoint_id()) ::
          :peer_id | :component_id
  def get_endpoint_id_type(state, endpoint_id) do
    case get_endpoint_group(state, endpoint_id) do
      :peers -> :peer_id
      :components -> :component_id
    end
  end

  @spec get_endpoint_group(state :: t(), endpoint_id :: endpoint_id()) ::
          :components | :peers
  def get_endpoint_group(state, endpoint_id) when component_exists?(state, endpoint_id),
    do: :components

  def get_endpoint_group(state, endpoint_id) when peer_exists?(state, endpoint_id),
    do: :peers

  @spec validate_subscription_mode(component :: Component.t() | nil) :: :ok | {:error, any()}
  def validate_subscription_mode(nil), do: {:error, :component_not_exists}

  def validate_subscription_mode(%{properties: %{subscribe_mode: :auto}}),
    do: {:error, :invalid_subscribe_mode}

  def validate_subscription_mode(%{properties: %{subscribe_mode: :manual}}), do: :ok
  def validate_subscription_mode(_not_properties), do: {:error, :invalid_component_type}

  defp check_component_allowed_in_room(type, %{
         config: %{video_codec: video_codec},
         components: components
       })
       when type in [HLS, Recording] do
    cond do
      video_codec != :h264 ->
        {:error, :incompatible_codec}

      component_already_present?(type, components) ->
        {:error, :reached_components_limit}

      true ->
        :ok
    end
  end

  defp check_component_allowed_in_room(RTSP, %{config: %{video_codec: video_codec}}) do
    # Right now, RTSP component can only publish H264, so there's no point adding it
    # to a room which allows another video codec, e.g. VP8
    if video_codec == :h264,
      do: :ok,
      else: {:error, :incompatible_codec}
  end

  defp check_component_allowed_in_room(_component_type, _state), do: :ok

  defp component_already_present?(type, components),
    do: components |> Map.values() |> Enum.any?(&(&1.type == type))

  defp maybe_schedule_peerless_purge(%{config: %{peerless_purge_timeout: nil}} = state), do: state

  defp maybe_schedule_peerless_purge(%{config: config, peers: peers} = state) do
    if all_peers_disconnected?(peers) do
      last_peer_left = Klotho.monotonic_time(:millisecond)

      Klotho.send_after(config.peerless_purge_timeout * 1000, self(), :peerless_purge)

      %{state | last_peer_left: last_peer_left}
    else
      state
    end
  end

  defp maybe_schedule_peer_purge(%{config: %{peer_disconnected_timeout: nil}} = state, _peer),
    do: state

  defp maybe_schedule_peer_purge(%{config: config} = state, peer) do
    case fetch_peer(state, peer.id) do
      {:ok, peer} when peer.status == :disconnected ->
        last_time_connected = Klotho.monotonic_time(:millisecond)

        Klotho.send_after(config.peer_disconnected_timeout * 1000, self(), {:peer_purge, peer.id})

        put_in(state, [:peers, peer.id, :last_time_connected], last_time_connected)

      _other ->
        state
    end
  end

  defp all_peers_disconnected?(peers) do
    peers |> Map.values() |> Enum.all?(&(&1.status == :disconnected))
  end
end
