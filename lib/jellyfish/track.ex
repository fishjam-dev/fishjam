defmodule Jellyfish.Track do
  @moduledoc """
  Represents a media track send from Component or Peer.
  """

  use Bunch.Access

  alias Membrane.RTC.Engine.Message.{TrackAdded, TrackMetadataUpdated}

  @enforce_keys [:id, :type]
  defstruct @enforce_keys ++ [:metadata]

  @type id() :: String.t()

  @type t() :: %__MODULE__{
          id: id(),
          type: :audio | :video,
          metadata: nil | any()
        }

  @spec from_track_message(TrackAdded.t() | TrackMetadataUpdated.t()) :: t()
  def from_track_message(%type{} = message)
      when type in [TrackAdded, TrackMetadataUpdated] do
    %__MODULE__{
      id: message.track_id,
      type: message.track_type,
      metadata: message.track_metadata
    }
  end
end
