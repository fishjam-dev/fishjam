defmodule Jellyfish.ServerMessage.EventType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :EVENT_TYPE_UNSPECIFIED, 0
  field :EVENT_TYPE_SERVER_NOTIFICATION, 1
  field :EVENT_TYPE_METRICS, 2
end

defmodule Jellyfish.ServerMessage.RoomCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.PeerConnected do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.PeerDisconnected do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.PeerCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.ComponentCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Jellyfish.ServerMessage.Authenticated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule Jellyfish.ServerMessage.AuthRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :token, 1, type: :string
end

defmodule Jellyfish.ServerMessage.SubscribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :event_type, 1,
    type: Jellyfish.ServerMessage.EventType,
    json_name: "eventType",
    enum: true
end

defmodule Jellyfish.ServerMessage.SubscribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :event_type, 1,
    type: Jellyfish.ServerMessage.EventType,
    json_name: "eventType",
    enum: true
end

defmodule Jellyfish.ServerMessage.RoomCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.RoomDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.MetricsReport do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :metrics, 1, type: :string
end

defmodule Jellyfish.ServerMessage.HlsPlayable do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Jellyfish.ServerMessage.HlsUploaded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.HlsUploadCrashed do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :content, 0

  field :room_crashed, 1,
    type: Jellyfish.ServerMessage.RoomCrashed,
    json_name: "roomCrashed",
    oneof: 0

  field :peer_connected, 2,
    type: Jellyfish.ServerMessage.PeerConnected,
    json_name: "peerConnected",
    oneof: 0

  field :peer_disconnected, 3,
    type: Jellyfish.ServerMessage.PeerDisconnected,
    json_name: "peerDisconnected",
    oneof: 0

  field :peer_crashed, 4,
    type: Jellyfish.ServerMessage.PeerCrashed,
    json_name: "peerCrashed",
    oneof: 0

  field :component_crashed, 5,
    type: Jellyfish.ServerMessage.ComponentCrashed,
    json_name: "componentCrashed",
    oneof: 0

  field :authenticated, 6, type: Jellyfish.ServerMessage.Authenticated, oneof: 0

  field :auth_request, 7,
    type: Jellyfish.ServerMessage.AuthRequest,
    json_name: "authRequest",
    oneof: 0

  field :subscribe_request, 8,
    type: Jellyfish.ServerMessage.SubscribeRequest,
    json_name: "subscribeRequest",
    oneof: 0

  field :subscribe_response, 9,
    type: Jellyfish.ServerMessage.SubscribeResponse,
    json_name: "subscribeResponse",
    oneof: 0

  field :room_created, 10,
    type: Jellyfish.ServerMessage.RoomCreated,
    json_name: "roomCreated",
    oneof: 0

  field :room_deleted, 11,
    type: Jellyfish.ServerMessage.RoomDeleted,
    json_name: "roomDeleted",
    oneof: 0

  field :metrics_report, 12,
    type: Jellyfish.ServerMessage.MetricsReport,
    json_name: "metricsReport",
    oneof: 0

  field :hls_playable, 13,
    type: Jellyfish.ServerMessage.HlsPlayable,
    json_name: "hlsPlayable",
    oneof: 0

  field :hls_uploaded, 14,
    type: Jellyfish.ServerMessage.HlsUploaded,
    json_name: "hlsUploaded",
    oneof: 0

  field :hls_upload_crashed, 15,
    type: Jellyfish.ServerMessage.HlsUploadCrashed,
    json_name: "hlsUploadCrashed",
    oneof: 0
end
