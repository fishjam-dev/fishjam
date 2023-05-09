defmodule Jellyfish.Server.ControlMessage.RoomCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
end

defmodule Jellyfish.Server.ControlMessage.PeerConnected do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.Server.ControlMessage.PeerDisconnected do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.Server.ControlMessage.PeerCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :peer_id, 2, type: :string, json_name: "peerId"
end

defmodule Jellyfish.Server.ControlMessage.ComponentCrashed do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :room_id, 1, type: :string, json_name: "roomId"
  field :component_id, 2, type: :string, json_name: "componentId"
end

defmodule Jellyfish.Server.ControlMessage.Authenticated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.Server.ControlMessage.AuthRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :token, 1, type: :string
end

defmodule Jellyfish.Server.ControlMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :content, 0

  field :roomCrashed, 1, type: Jellyfish.Server.ControlMessage.RoomCrashed, oneof: 0
  field :peerConnected, 2, type: Jellyfish.Server.ControlMessage.PeerConnected, oneof: 0
  field :peerDisconnected, 3, type: Jellyfish.Server.ControlMessage.PeerDisconnected, oneof: 0
  field :peerCrashed, 4, type: Jellyfish.Server.ControlMessage.PeerCrashed, oneof: 0
  field :componentCrashed, 5, type: Jellyfish.Server.ControlMessage.ComponentCrashed, oneof: 0
  field :authenticated, 6, type: Jellyfish.Server.ControlMessage.Authenticated, oneof: 0
  field :authRequest, 7, type: Jellyfish.Server.ControlMessage.AuthRequest, oneof: 0
end
