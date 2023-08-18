defmodule Jellyfish.Component.HLS.LLStorage do
  @moduledoc false

  @behaviour Membrane.HTTPAdaptiveStream.Storage

  alias Jellyfish.Component.HLS.{EtsHelper, RequestHandler}
  alias Jellyfish.Room

  @enforce_keys [:directory, :room_id]
  defstruct @enforce_keys ++
              [partial_sn: 0, segment_sn: 0, partials_in_ets: []]

  @type partial_ets_key :: String.t()
  @type sequence_number :: non_neg_integer()
  @type partial_in_ets ::
          {{segment_sn :: sequence_number(), partial_sn :: sequence_number()}, partial_ets_key()}

  @type t :: %__MODULE__{
          directory: Path.t(),
          room_id: Room.id(),
          partial_sn: sequence_number(),
          segment_sn: sequence_number(),
          partials_in_ets: [partial_in_ets()]
        }

  @ets_duration_in_segments 4

  @impl true
  def init(%__MODULE__{directory: directory, room_id: room_id}) do
    with :ok <- EtsHelper.add_room(room_id) do
      %__MODULE__{room_id: room_id, directory: directory}
    else
      {:error, :already_exists} -> {:error, :cannot_create_ets_table}
    end
  end

  @impl true
  def store(_parent_id, name, content, metadata, context, state) do
    case context do
      %{mode: :binary, type: :segment} ->
        {:ok, state}

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
         %__MODULE__{
           directory: directory
         } = state
       ) do
    result = write_to_file(directory, filename, content)

    unless filename == "index.m3u8" do
      add_manifest_to_ets(filename, content, state)
      send_update(filename, state)
    end

    {result, state}
  end

  defp add_manifest_to_ets(filename, manifest, %{room_id: room_id}) do
    if String.contains?(filename, "_delta.m3u8") do
      EtsHelper.update_delta_manifest(room_id, manifest)
    else
      EtsHelper.update_manifest(room_id, manifest)
    end
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
    EtsHelper.add_partial(room_id, content, filename, offset)

    partial = {segment_sn, partial_sn}
    %{state | partials_in_ets: [{partial, {filename, offset}} | partials_in_ets]}
  end

  defp remove_partials_from_ets(
         %{partials_in_ets: partials_in_ets, segment_sn: curr_segment_sn, room_id: room_id} =
           state
       ) do
    # Remove all partials that are at least @ets_duration_in_segments behind
    partials_in_ets =
      Enum.filter(partials_in_ets, fn {{segment_sn, _partial_sn}, {filename, offset}} ->
        if segment_sn + @ets_duration_in_segments <= curr_segment_sn do
          EtsHelper.delete_partial(room_id, filename, offset)
          false
        else
          true
        end
      end)

    %{state | partials_in_ets: partials_in_ets}
  end

  defp send_update(filename, %{
         room_id: room_id,
         segment_sn: segment_sn,
         partial_sn: partial_sn
       }) do
    if String.contains?(filename, "_delta.m3u8") do
      EtsHelper.update_delta_recent_partial(room_id, {segment_sn, partial_sn})
      RequestHandler.update_delta_recent_partial(room_id, {segment_sn, partial_sn})
    else
      EtsHelper.update_recent_partial(room_id, {segment_sn, partial_sn})
      RequestHandler.update_recent_partial(room_id, {segment_sn, partial_sn})
    end
  end

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

  defp write_to_file(directory, filename, content, write_options \\ []) do
    directory
    |> Path.join(filename)
    |> File.write(content, write_options)
  end
end
