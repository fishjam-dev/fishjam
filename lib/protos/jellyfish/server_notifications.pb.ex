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
end
