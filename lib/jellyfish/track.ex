defmodule Jellyfish.Track do
  @moduledoc """
  Represents a media track send from Component or Peer.
  """

  use Bunch.Access

  alias Membrane.RTC.Engine.Message.TrackAdded

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
end
