defmodule Jellyfish.Server.ControlMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :content, 0

  field :roomCrashed, 1, type: Jellyfish.Server.ServerNotification.RoomNotification, oneof: 0
  field :peerConnected, 2, type: Jellyfish.Server.ServerNotification.PeerNotification, oneof: 0
  field :peerDisconnected, 3, type: Jellyfish.Server.ServerNotification.PeerNotification, oneof: 0
  field :peerCrashed, 4, type: Jellyfish.Server.ServerNotification.PeerNotification, oneof: 0

  field :componentCrashed, 5,
    type: Jellyfish.Server.ServerNotification.ComponentNotification,
    oneof: 0

  field :authenticated, 6, type: Jellyfish.Server.ServerNotification.Authenticated, oneof: 0
  field :authRequest, 7, type: Jellyfish.Server.ClientMessage.TokenMessage, oneof: 0
end

defmodule Jellyfish.Server.ClientMessage.TokenMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :token, 1, type: :string
end

defmodule Jellyfish.Server.ClientMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.Server.ServerNotification.Authenticated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.Server.ServerNotification.RoomNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :roomId, 1, type: :string
end

defmodule Jellyfish.Server.ServerNotification.PeerNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :roomId, 1, type: :string
  field :peerId, 2, type: :string
end

defmodule Jellyfish.Server.ServerNotification.ComponentNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :roomId, 1, type: :string
  field :componentId, 2, type: :string
end

defmodule Jellyfish.Server.ServerNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end