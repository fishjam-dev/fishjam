defmodule Jellyfish.Track do
  @moduledoc """
  Represents a media track send from Component or Peer.
  """

  use Bunch.Access

  alias Membrane.RTC.Engine.Message.TrackAdded
  alias Membrane.RTC.Engine.Track

  @enforce_keys [:id, :type, :encoding]
  defstruct @enforce_keys ++ [:metadata]

  @type id() :: String.t()

  @type t() :: %__MODULE__{
          id: id(),
          type: :audio | :video,
          encoding: atom(),
          metadata: nil | any()
        }

  @spec from_track_added_message(TrackAdded.t()) :: t()
  def from_track_added_message(message) do
    %__MODULE__{
      id: message.track_id,
      type: message.track_type,
      encoding: message.track_encoding
    }
  end

  @spec from_engine_track(Track.t()) :: t()
  def from_engine_track(engine_track) do
    %__MODULE__{
      id: engine_track.id,
      type: engine_track.type,
      encoding: engine_track.encoding,
      metadata: engine_track.metadata
    }
  end
end
