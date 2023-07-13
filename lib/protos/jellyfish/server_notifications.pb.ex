defmodule Jellyfish.ServerMessage.SubscribeRequest.ServerNotification.Option do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :OPTION_UNSPECIFIED, 0
  field :OPTION_ALL, 1
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Config.Encoding do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :ENCODING_UNSPECIFIED, 0
  field :ENCODING_H264, 1
  field :ENCODING_VP8, 2
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer.Type do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :TYPE_UNSPECIFIED, 0
  field :TYPE_WEBRTC, 1
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer.Status do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :STATUS_UNSPECIFIED, 0
  field :STATUS_CONNECTED, 1
  field :STATUS_DISCONNECTED, 2
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Component.Type do
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

defmodule Jellyfish.ServerMessage.SubscribeRequest.ServerNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :room_id, 0

  field :id, 1, type: :string, oneof: 0

  field :option, 2,
    type: Jellyfish.ServerMessage.SubscribeRequest.ServerNotification.Option,
    enum: true,
    oneof: 0
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
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Config do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :max_peers, 1, type: :uint32, json_name: "maxPeers"

  field :video_encoding, 2,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Config.Encoding,
    json_name: "videoEncoding",
    enum: true
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string

  field :type, 2,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer.Type,
    enum: true

  field :status, 3,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer.Status,
    enum: true
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Component do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string

  field :type, 2,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Component.Type,
    enum: true
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomState do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string
  field :config, 2, type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Config

  field :peers, 3,
    repeated: true,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Peer

  field :components, 4,
    repeated: true,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState.Component
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomsState do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :rooms, 1, repeated: true, type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse.RoomNotFound do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :id, 1, type: :string
end

defmodule Jellyfish.ServerMessage.SubscriptionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :content, 0

  field :id, 1, type: :string

  field :room_state, 2,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomState,
    json_name: "roomState",
    oneof: 0

  field :rooms_state, 3,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomsState,
    json_name: "roomsState",
    oneof: 0

  field :room_not_found, 4,
    type: Jellyfish.ServerMessage.SubscriptionResponse.RoomNotFound,
    json_name: "roomNotFound",
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

  field :subscription_response, 9,
    type: Jellyfish.ServerMessage.SubscriptionResponse,
    json_name: "subscriptionResponse",
    oneof: 0

  field :room_created, 10,
    type: Jellyfish.ServerMessage.RoomCreated,
    json_name: "roomCreated",
    oneof: 0

  field :room_deleted, 11,
    type: Jellyfish.ServerMessage.RoomDeleted,
    json_name: "roomDeleted",
    oneof: 0
end
