defmodule Jellyfish.Component.HLS.Broadcaster do
  @moduledoc """
  Module representing room.
  """

  # use Bunch.Access
  use GenServer

  require Logger

  # alias Jellyfish.Component
  # alias Jellyfish.Peer
  # alias Membrane.ICE.TURNManager
  # alias Membrane.RTC.Engine
  alias Membrane.HTTPAdaptiveStream.Storages.SendStorage
  alias Phoenix.PubSub

  # @enforce_keys [
  #   :id,
  #   :config,
  #   :engine_pid,
  #   :network_options
  # ]
  # defstruct @enforce_keys ++ [components: %{}, peers: %{}]

  # @type id :: String.t()
  # @type max_peers :: non_neg_integer() | nil

  @typedoc """
  This module contains:
  * `id` - room id
  * `config` - configuration of room. For example you can specify maximal number of peers
  * `components` - map of components
  * `peers` - map of peers
  * `engine` - pid of engine
  """
  # @type t :: %__MODULE__{
  #         id: id(),
  #         config: %{max_peers: max_peers(), simulcast?: boolean()},
  #         components: %{Component.id() => Component.t()},
  #         peers: %{Peer.id() => Peer.t()},
  #         engine_pid: pid(),
  #         network_options: map()
  #       }

  def new([directory: _directory, room_id: room_id] = config) do
    name = for_room(room_id)
    {:ok, _pid} = GenServer.start_link(__MODULE__, config, name: name)
    name
  end

  def for_room(room_id), do: :"HLS_Broadcaster_#{room_id}"

  def request_partial_manifest(room_id, filename, segment, partial) do
    # IO.inspect("request_partial_manifest")
    PubSub.subscribe(Jellyfish.PubSub, "manifest_update")
    manifest = get_partial_manifest(room_id, filename, segment, partial)
    PubSub.unsubscribe(Jellyfish.PubSub, "manifest_update")
    manifest
  end

  def request_partial_segment(room_id, filename, byte_range) do
    IO.inspect("start request_partial_segment")
    byte_offset = byte_range
    |> String.split("-")
    |> Enum.at(-1)
    |> String.to_integer


    PubSub.subscribe(Jellyfish.PubSub, "segment_update")
    partial = get_partial_segment(room_id, filename, byte_offset + 1)
    PubSub.unsubscribe(Jellyfish.PubSub, "segment_update")
    partial
  end

  defp get_partial_manifest(room_id, filename, segment, partial) do
    case GenServer.call(for_room(room_id), {:get_manifest, filename, segment, partial}) do
      {:ok, manifest} ->
        manifest
      {:error, :not_found} ->
        receive do
          _filename -> get_partial_manifest(room_id, filename, segment, partial)
          # {manifest, %{"SEGMENT_NUMBER" => segment_number, "PARTIAL_NUMBER" => partial_number}} when (segment_number == segment and partial_number >= partial) or segment_number > segment ->
          #   manifest
        end
    end
  end

  def get_partial_segment(room_id, filename, byte_offset) do
    case GenServer.call(for_room(room_id), {:get_partial, filename, byte_offset}) |> IO.inspect(label: "get_partial" ) do
      # test ->
        # IO.inspect(test, label: "test: request_partial_segment")
      {:ok, partial} ->
        IO.inspect(partial, label: "found: request_partial_segment")
        partial
      {:error, :not_found} ->
        receive do
          _filename -> get_partial_segment(room_id, filename, byte_offset)
            # IO.inspect({partial, sth}, label: "received: request_partial_segment")
            # partial
          # {partial, %{byte_offset: ^byte_offset}} -> partial
        end
    end
  end


  @impl true
  def init([directory: directory, room_id: room_id]) do
    state = %{
      directory: directory,
      room_id: room_id,
      manifests: %{},
      partial_segments: %{},
      last_segment: nil
    }
    {:ok, state, :hibernate}
  end

  @impl true
  def handle_info({SendStorage, :store, %{type: :header, contents: contents, name: name, mode: mode}}, state) do
    # IO.inspect(contents, label: "other_" <> state.room_id)
    {:noreply, state, {:continue, {:save_file, name, contents, [mode]}}}
  end

  @impl true
  def handle_info({SendStorage, :store, %{type: :manifest, contents: contents, name: name, mode: mode}}, state) do
    # IO.inspect(contents, label: "manifest_" <> state.room_id)
    state = put_in(state, Enum.map([:manifests, name, :content], &Access.key(&1, %{})), contents)
    with {:ok, metadata} <- get_last_segment_info(contents) do
      current_segment_number = Map.get(metadata, "SEGMENT_NUMBER")
      {{_current_segment_number, current_partial_number}, state} = get_and_update_in(state, Enum.map([:manifests, name, :last_partial], &Access.key(&1, %{})), fn value ->
        case value do
          {^current_segment_number, partial} -> {{current_segment_number, partial + 1}, {current_segment_number, partial + 1}}
          _other -> {{current_segment_number, 0}, {current_segment_number, 0}}
        end
      end)
      metadata = Map.put(metadata, "PARTIAL_NUMBER", current_partial_number)
      # IO.inspect(in_manifest)
      # IO.inspect(state.manifests)
      {:noreply, state, {:continue, {:broadcast, "manifest_update", name, contents, metadata, [mode]}}}
    else
      {:error, :no_partial_segments} ->
        {:noreply, state, {:continue, {:save_file, name, contents, [mode]}}}
    end
  end

  @impl true
  def handle_info({SendStorage, :store, %{type: :partial_segment, contents: contents, name: name, mode: mode, metadata: %{byte_offset: byte_offset} = metadata}}, state) do
    IO.inspect("#{name}_#{byte_offset}", label: "partial_segment")
    state = put_in(state, Enum.map([:partial_segments, name, byte_offset], &Access.key(&1, %{})), contents)
    {:noreply, state, {:continue, {:broadcast, "segment_update", name, contents, metadata, [:append, mode]}}}
  end

  @impl true
  def handle_info({SendStorage, :store, %{type: :segment, name: name, contents: contents}}, state) do
    # IO.inspect(message, label: "other_" <> state.room_id)
    # {_last_segment, state} = pop_in(state, [:partial_segments, state.last_segment])
    state = Map.put(state, :last_segment, name)
    {:noreply, state, {:continue, {:save_file, name, contents, []}}}
  end

  @impl true
  def handle_continue({:broadcast, message, filename, content, metadata, modes}, state) do
    PubSub.broadcast(
      Jellyfish.PubSub,
      message,
      {:filename}
    )
    IO.inspect(message, label: filename)
    {:noreply, state, {:continue, {:save_file, filename, content, modes}}}
  end

  @impl true
  def handle_continue({:save_file, filename, content, modes}, %{directory: directory} = state) do
    File.write(Path.join(directory, filename), content, modes)
    # IO.inspect(state, label: "state")
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_manifest, filename, segment, partial}, _from, %{manifests: manifests} = state) do
    response = case manifests do
      %{^filename => %{last_partial: {segment_number, partial_number}, content: content}} when (segment_number == segment and partial_number >= partial) or segment_number > segment ->
        {:ok, content}
      _other -> {:error, :not_found}
    end
    {:reply, response, state}
  end

  @impl true
  def handle_call({:get_partial, filename, byte_offset}, _from, %{partial_segments: partial_segments} = state) do
    Map.get(partial_segments, filename) |> IO.inspect(label: "looking partial_segments: #{filename} offset: #{byte_offset}")
    response = case partial_segments do
      # content ->
      #   IO.inspect(content, label: "get_partial: #{filename}-#{byte_offset}")
      #   {:ok, content}
      %{^filename => %{^byte_offset => content }} -> {:ok, content}
      _other -> {:error, :not_found}
    end
    {:reply, response, state}
  end

  # @impl true
  # def handle_call({:get_partial, filename, segment, partial}, _from, %{manifests: manifests} = state) do
  #   response = case manifests do
  #     %{^filename => %{last_partial: {current_segment, current_partial}, content: content}} when segment_in_manifest?({current_segment, current_partial}, {segment, partial}) ->
  #       {:ok, content}
  #     _other -> {:error, :not_found}
  #   end
  #   {:reply, response, state}
  # end

  defp get_last_segment_info(manifest) do
    segments = manifest
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "#EXT-X-PART:"))

    unless Enum.empty?(segments) do
      metadata = segments
      |> Enum.at(-1)
      |> String.replace("\"", "")
      |> String.split(",")
      |> Enum.map(fn elem -> String.split(elem, "=")
      |> List.to_tuple end)
      |> Map.new
      last_partial_byte_offset = get_partial_byte_offset(metadata)
      last_partial_segment_number = get_partial_number(metadata)
      {:ok, Map.merge(metadata, %{"BYTE_OFFSET" => last_partial_byte_offset, "SEGMENT_NUMBER" => last_partial_segment_number})}
    else
      {:error, :no_partial_segments}
    end
  end

  defp get_partial_number(metadata) do
    filename = Map.get(metadata, "URI")
    [_type, "segment", number, _rest] = String.split(filename, "_")
    String.to_integer(number)
  end

  defp get_partial_byte_offset(metadata) do
    Map.get(metadata, "BYTERANGE")
    |> String.split("@")
    |> Enum.at(-1)
    |> String.to_integer()
  end

  # defp segment_in_manifest?({segment_number, partial_number}, {segment, partial}) do
  #   (segment_number == segment and partial_number >= partial) or segment_number > segment
  # end
end
