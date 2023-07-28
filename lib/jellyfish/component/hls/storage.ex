defmodule Jellyfish.Component.HLS.FileStorage do
  @moduledoc """
  `MembraneLive.HTTPAdaptiveStream.FileStorage` implementation.
  Supports LL-HLS and notifies that a partial segment has been saved via `Phoenix.PubSub`.
  """
  @behaviour Membrane.HTTPAdaptiveStream.Storage

  require Membrane.Logger

  alias Jellyfish.Component.HLS.Helpers
  alias Phoenix.PubSub

  @enforce_keys [:directory, :second_segment_ready?]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          directory: Path.t(),
          second_segment_ready?: boolean()
        }

  defmodule Config do
    @moduledoc false
    @enforce_keys [:directory]

    defstruct @enforce_keys

    @type t :: %__MODULE__{
            directory: Path.t()
          }
  end

  @ets_key :partial_segments
  @remove_partial_timeout_ms 5000

  @impl true
  def init(config) do
    config
    |> Map.merge(%{second_segment_ready?: false})
    |> Map.from_struct()
    |> then(&struct!(__MODULE__, &1))
  end

  @impl true
  def store(
        _parent_id,
        segment_filename,
        content,
        _metadata,
        %{mode: :binary, type: :segment},
        %__MODULE__{directory: directory} = state
      ) do
    result = File.write(Path.join(directory, segment_filename), content, [:binary])
    {result, state}
  end

  @impl true
  def store(
        _parent_id,
        segment_filename,
        contents,
        %{byte_offset: offset},
        %{mode: :binary, type: :partial_segment},
        %__MODULE__{directory: directory} = state
      ) do
    result = File.write(Path.join(directory, segment_filename), contents, [:binary, :append])

    add_partial_to_ets("#{segment_filename}_#{offset}", contents)

    Task.start(fn ->
      Process.sleep(@remove_partial_timeout_ms)
      remove_partial_from_ets("#{segment_filename}_#{offset}")
    end)

    {result, state}
  end

  def store(
        _parent_id,
        filename,
        contents,
        _metadata,
        %{mode: :binary, type: :header},
        %__MODULE__{directory: directory} = state
      ) do
    {File.write(Path.join(directory, filename), contents, [:binary]), state}
  end

  @impl true
  def store(
        _parent_id,
        filename,
        contents,
        _metadata,
        %{mode: :text, type: :manifest},
        %__MODULE__{directory: directory} = state
      ) do
    result = File.write(Path.join(directory, filename), contents)

    state = maybe_send_first_segment_notification(state, contents)

    if state.second_segment_ready? do
      notify_playlist_update(contents)
    end

    {result, state}
  end

  @impl true
  def remove(_parent_id, name, _ctx, %__MODULE__{directory: location} = state) do
    {File.rm(Path.join(location, name)), state}
  end

  defp notify_playlist_update(contents) do
    case Helpers.get_last_partial(contents) do
      {segment_filename, segment, partial} ->
        PubSub.broadcast(
          Jellyfish.PubSub,
          segment_filename,
          {:manifest_update_partial, segment, partial}
        )

        {:ok, segment_filename}

      {:error, message} ->
        {:error, message}
    end
  end

  defp maybe_send_first_segment_notification(
         %__MODULE__{second_segment_ready?: true} = state,
         _contents
       ),
       do: state

  defp maybe_send_first_segment_notification(%__MODULE__{} = state, contents),
    do: %{state | second_segment_ready?: String.contains?(contents, "_segment_1_")}

  defp remove_partial_from_ets(partial), do: :ets.delete(@ets_key, partial)

  defp add_partial_to_ets(partial, content), do: :ets.insert(@ets_key, {partial, content})
end
