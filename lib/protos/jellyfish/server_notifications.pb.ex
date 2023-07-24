defmodule Jellyfish.ServerMessage.RoomState.Config.Codec do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :CODEC_UNSPECIFIED, 0
  field :CODEC_H264, 1
  field :CODEC_VP8, 2
end

defmodule Jellyfish.ServerMessage.RoomState.Peer.Type do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :TYPE_UNSPECIFIED, 0
  field :TYPE_WEBRTC, 1
end

defmodule Jellyfish.ServerMessage.RoomState.Peer.Status do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :STATUS_UNSPECIFIED, 0
  field :STATUS_CONNECTED, 1
  field :STATUS_DISCONNECTED, 2
end

defmodule Jellyfish.ServerMessage.RoomState.Component.Type do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :TYPE_UNSPECIFIED, 0
  field :TYPE_HLS, 1
  field :TYPE_RTSP, 2
end

defmodule Jellyfish.ServerMessage.RoomCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.PeerConnected do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.PeerDisconnected do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.PeerCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.ServerMessage.ComponentCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Jellyfish.ServerMessage.Authenticated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.ServerMessage.AuthRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :token, 1, type: :string
end

defmodule Jellyfish.ServerMessage.RoomState.Config do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :max_peers, 1, type: :uint32, json_name: "maxPeers"

  field :video_codec, 2,
    type: Jellyfish.ServerMessage.RoomState.Config.Codec,
    json_name: "videoCodec",
    enum: true
end

defmodule Jellyfish.ServerMessage.RoomState.Peer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string
  field :type, 2, type: Jellyfish.ServerMessage.RoomState.Peer.Type, enum: true
  field :status, 3, type: Jellyfish.ServerMessage.RoomState.Peer.Status, enum: true
end

defmodule Jellyfish.ServerMessage.RoomState.Component do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string
  field :type, 2, type: Jellyfish.ServerMessage.RoomState.Component.Type, enum: true
end

defmodule Jellyfish.ServerMessage.RoomState do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string
  field :config, 2, type: Jellyfish.ServerMessage.RoomState.Config
  field :peers, 3, repeated: true, type: Jellyfish.ServerMessage.RoomState.Peer
  field :components, 4, repeated: true, type: Jellyfish.ServerMessage.RoomState.Component
end

defmodule Jellyfish.ServerMessage.SubscribeRequest.ServerNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.ServerMessage.SubscribeRequest.Metrics do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.ServerMessage.SubscribeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :event_type, 0

  field :id, 1, type: :string

  field :server_notification, 2,
    type: Jellyfish.ServerMessage.SubscribeRequest.ServerNotification,
    json_name: "serverNotification",
    oneof: 0

  field :metrics, 3, type: Jellyfish.ServerMessage.SubscribeRequest.Metrics, oneof: 0
end

defmodule Jellyfish.ServerMessage.SubscribeResponse.RoomStates do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :rooms, 1, repeated: true, type: Jellyfish.ServerMessage.RoomState
end

defmodule Jellyfish.ServerMessage.SubscribeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :content, 0

  field :id, 1, type: :string

  field :room_states, 2,
    type: Jellyfish.ServerMessage.SubscribeResponse.RoomStates,
    json_name: "roomStates",
    oneof: 0
end

defmodule Jellyfish.ServerMessage.RoomCreated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.RoomDeleted do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.MetricsReport do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :metrics, 1, type: :string
end

defmodule Jellyfish.ServerMessage.RoomStateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage.RoomNotFound do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.ServerMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

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

  field :room_state_request, 13,
    type: Jellyfish.ServerMessage.RoomStateRequest,
    json_name: "roomStateRequest",
    oneof: 0

  field :room_state, 14, type: Jellyfish.ServerMessage.RoomState, json_name: "roomState", oneof: 0

  field :room_not_found, 15,
    type: Jellyfish.ServerMessage.RoomNotFound,
    json_name: "roomNotFound",
    oneof: 0
end
