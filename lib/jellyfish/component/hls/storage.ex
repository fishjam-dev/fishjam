defmodule Jellyfish.Component.HLS.Storage do
  @moduledoc false

  @behaviour Membrane.HTTPAdaptiveStream.Storage

  alias Jellyfish.Room

  @enforce_keys [:directory, :room_id]
  defstruct @enforce_keys ++ [partial_sn: nil, segment_sn: 0, partials_in_ets: []]

  @type partial_ets_key :: String.t()
  @type sequence_number :: non_neg_integer()
  @type partial_in_ets ::
          {{segment_sn :: sequence_number(), partial_sn :: sequence_number()}, partial_ets_key()}

  @type t :: %__MODULE__{
          directory: Path.t(),
          room_id: Room.id(),
          partial_sn: sequence_number() | nil,
          segment_sn: sequence_number(),
          partials_in_ets: [partial_in_ets()]
        }

  @manifest_key :manifest
  @last_partial_key :last_partial

  @ets_duration_in_segments 4

  @impl true
  def init(%{directory: directory, room_id: room_id}) do
    # Initializes ets storage that will serve partial segments and manifests
    :ets.new({__MODULE__, room_id}, [:public, :set, :named_table])

    %__MODULE__{room_id: room_id, directory: directory}
  end

  @impl true
  def store(_parent_id, name, content, metadata, context, state) do
    case context do
      %{mode: :binary, type: :segment} ->
        store_segment(name, content, state)

      %{mode: :binary, type: :partial_segment} ->
        store_partial_segment(name, content, metadata, state)

      %{mode: :binary, type: :header} ->
        store_header(name, content, state)

      %{mode: :text, type: :manifest} ->
        store_manifest(name, content, state)
    end
  end

  @impl true
  def remove(_parent_id, name, _ctx, %__MODULE__{directory: directory} = state) do
    result =
      directory
      |> Path.join(name)
      |> File.rm()

    {result, state}
  end

  defp store_segment(
         filename,
         content,
         %{directory: directory} = state
       ) do
    result = write_to_file(directory, filename, content, [:binary])
    {result, state}
  end

  defp store_partial_segment(
         filename,
         content,
         %{byte_offset: offset, sequence_number: sequence_number},
         %__MODULE__{directory: directory} = state
       ) do
    result = write_to_file(directory, filename, content, [:binary, :append])

    state =
      state
      |> update_sequence_numbers(sequence_number)
      |> add_partial_to_ets(filename, offset, content)

    {result, state}
  end

  defp store_header(
         filename,
         content,
         %__MODULE__{directory: directory} = state
       ) do
    result = write_to_file(directory, filename, content, [:binary])
    {result, state}
  end

  defp store_manifest(
         filename,
         content,
         %__MODULE__{directory: directory} = state
       ) do
    result = write_to_file(directory, filename, content)

    add_manifest_to_ets(content, state)
    send_update(state)

    {result, state}
  end

  defp write_to_file(directory, filename, content, write_options \\ []) do
    directory
    |> Path.join(filename)
    |> File.write(content, write_options)
  end

  # first partial
  defp update_sequence_numbers(%{partial_sn: nil} = state, new_partial_sn),
    do: %{state | partial_sn: new_partial_sn}

  defp update_sequence_numbers(
         %{segment_sn: segment_sn, partial_sn: partial_sn} = state,
         new_partial_sn
       ) do
    new_segment? = new_partial_sn < partial_sn

    if new_segment? do
      state = %{state | segment_sn: segment_sn + 1, partial_sn: new_partial_sn}
      # If there is a new segment we want to remove partials that are to old from ets
      remove_partials_from_ets(state)
    else
      %{state | partial_sn: new_partial_sn}
    end
  end

  defp remove_partials_from_ets(
         %{partials_in_ets: partials_in_ets, segment_sn: curr_segment_sn, room_id: room_id} =
           state
       ) do
    # Remove all partials that are at least @ets_duration_in_segments behind
    partials_in_ets =
      Enum.filter(partials_in_ets, fn {{segment_sn, _partial_sn}, key} ->
        if segment_sn + @ets_duration_in_segments <= curr_segment_sn do
          :ets.delete({__MODULE__, room_id}, key)
          false
        else
          true
        end
      end)

    %{state | partials_in_ets: partials_in_ets}
  end

  defp add_partial_to_ets(
         %{
           room_id: room_id,
           partials_in_ets: partials_in_ets,
           segment_sn: segment_sn,
           partial_sn: partial_sn
         } = state,
         filename,
         offset,
         content
       ) do
    key = "#{filename}_#{offset}"
    partial = {segment_sn, partial_sn}

    :ets.insert({__MODULE__, room_id}, {key, content})

    %{state | partials_in_ets: [{partial, key} | partials_in_ets]}
  end

  # In case of regular hls we don't want to send anything to ets
  defp add_manifest_to_ets(_manifest, %{partial_sn: nil}), do: nil

  defp add_manifest_to_ets(manifest, %{
         segment_sn: segment_sn,
         partial_sn: partial_sn,
         room_id: room_id
       }) do
    :ets.insert({__MODULE__, room_id}, {@manifest_key, manifest})
    :ets.insert({__MODULE__, room_id}, {@last_partial_key, {segment_sn, partial_sn}})
  end

  # In case of regular hls we don't want to send anything to ets
  defp send_update(%{partial_sn: nil}), do: nil

  defp send_update(%{room_id: _room_id, segment_sn: _segment_sn, partial_sn: _partial_sn}) do
    # Not implemented
    # PartialState.update(room_id, {segment_sn, partial_sn})
    nil
  end
end
