defmodule Fishjam.ServerMessage.EventType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :EVENT_TYPE_UNSPECIFIED, 0
  field :EVENT_TYPE_SERVER_NOTIFICATION, 1
  field :EVENT_TYPE_METRICS, 2
end

defmodule Fishjam.ServerMessage.TrackType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :TRACK_TYPE_UNSPECIFIED, 0
  field :TRACK_TYPE_VIDEO, 1
  field :TRACK_TYPE_AUDIO, 2
end

defmodule Fishjam.ServerMessage.RoomCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Fishjam.ServerMessage.PeerAdded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Fishjam.ServerMessage.PeerDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Fishjam.ServerMessage.PeerConnected do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Fishjam.ServerMessage.PeerDisconnected do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Fishjam.ServerMessage.PeerCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
  field :reason, 3, type: :string
end

defmodule Fishjam.ServerMessage.ComponentCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Fishjam.ServerMessage.Authenticated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule Fishjam.ServerMessage.AuthRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :token, 1, type: :string
end

defmodule Fishjam.ServerMessage.SubscribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :event_type, 1, type: Fishjam.ServerMessage.EventType, json_name: "eventType", enum: true
end

defmodule Fishjam.ServerMessage.SubscribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :event_type, 1, type: Fishjam.ServerMessage.EventType, json_name: "eventType", enum: true
end

defmodule Fishjam.ServerMessage.RoomCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Fishjam.ServerMessage.RoomDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Fishjam.ServerMessage.MetricsReport do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :metrics, 1, type: :string
end

defmodule Fishjam.ServerMessage.HlsPlayable do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Fishjam.ServerMessage.HlsUploaded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Fishjam.ServerMessage.HlsUploadCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Fishjam.ServerMessage.PeerMetadataUpdated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
  field :metadata, 3, type: :string
end

defmodule Fishjam.ServerMessage.Track do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :id, 1, type: :string
  field :type, 2, type: Fishjam.ServerMessage.TrackType, enum: true
  field :metadata, 3, type: :string
end

defmodule Fishjam.ServerMessage.TrackAdded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :endpoint_info, 0

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId", oneof: 0
  field :component_id, 3, type: :string, json_name: "componentId", oneof: 0
  field :track, 4, type: Fishjam.ServerMessage.Track
end

defmodule Fishjam.ServerMessage.TrackRemoved do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :endpoint_info, 0

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId", oneof: 0
  field :component_id, 3, type: :string, json_name: "componentId", oneof: 0
  field :track, 4, type: Fishjam.ServerMessage.Track
end

defmodule Fishjam.ServerMessage.TrackMetadataUpdated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :endpoint_info, 0

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId", oneof: 0
  field :component_id, 3, type: :string, json_name: "componentId", oneof: 0
  field :track, 4, type: Fishjam.ServerMessage.Track
end

defmodule Fishjam.ServerMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :content, 0

  field :room_crashed, 1,
    type: Fishjam.ServerMessage.RoomCrashed,
    json_name: "roomCrashed",
    oneof: 0

  field :peer_connected, 2,
    type: Fishjam.ServerMessage.PeerConnected,
    json_name: "peerConnected",
    oneof: 0

  field :peer_disconnected, 3,
    type: Fishjam.ServerMessage.PeerDisconnected,
    json_name: "peerDisconnected",
    oneof: 0

  field :peer_crashed, 4,
    type: Fishjam.ServerMessage.PeerCrashed,
    json_name: "peerCrashed",
    oneof: 0

  field :component_crashed, 5,
    type: Fishjam.ServerMessage.ComponentCrashed,
    json_name: "componentCrashed",
    oneof: 0

  field :authenticated, 6, type: Fishjam.ServerMessage.Authenticated, oneof: 0

  field :auth_request, 7,
    type: Fishjam.ServerMessage.AuthRequest,
    json_name: "authRequest",
    oneof: 0

  field :subscribe_request, 8,
    type: Fishjam.ServerMessage.SubscribeRequest,
    json_name: "subscribeRequest",
    oneof: 0

  field :subscribe_response, 9,
    type: Fishjam.ServerMessage.SubscribeResponse,
    json_name: "subscribeResponse",
    oneof: 0

  field :room_created, 10,
    type: Fishjam.ServerMessage.RoomCreated,
    json_name: "roomCreated",
    oneof: 0

  field :room_deleted, 11,
    type: Fishjam.ServerMessage.RoomDeleted,
    json_name: "roomDeleted",
    oneof: 0

  field :metrics_report, 12,
    type: Fishjam.ServerMessage.MetricsReport,
    json_name: "metricsReport",
    oneof: 0

  field :hls_playable, 13,
    type: Fishjam.ServerMessage.HlsPlayable,
    json_name: "hlsPlayable",
    oneof: 0

  field :hls_uploaded, 14,
    type: Fishjam.ServerMessage.HlsUploaded,
    json_name: "hlsUploaded",
    oneof: 0

  field :hls_upload_crashed, 15,
    type: Fishjam.ServerMessage.HlsUploadCrashed,
    json_name: "hlsUploadCrashed",
    oneof: 0

  field :peer_metadata_updated, 16,
    type: Fishjam.ServerMessage.PeerMetadataUpdated,
    json_name: "peerMetadataUpdated",
    oneof: 0

  field :track_added, 17,
    type: Fishjam.ServerMessage.TrackAdded,
    json_name: "trackAdded",
    oneof: 0

  field :track_removed, 18,
    type: Fishjam.ServerMessage.TrackRemoved,
    json_name: "trackRemoved",
    oneof: 0

  field :track_metadata_updated, 19,
    type: Fishjam.ServerMessage.TrackMetadataUpdated,
    json_name: "trackMetadataUpdated",
    oneof: 0

  field :peer_added, 20, type: Fishjam.ServerMessage.PeerAdded, json_name: "peerAdded", oneof: 0

  field :peer_deleted, 21,
    type: Fishjam.ServerMessage.PeerDeleted,
    json_name: "peerDeleted",
    oneof: 0
end
