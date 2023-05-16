defmodule Jellyfish.Peer.ControlMessage.Authenticated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule Jellyfish.Peer.ControlMessage.AuthRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :token, 1, type: :string
end

defmodule Jellyfish.Peer.ControlMessage.MediaEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field :data, 1, type: :string
end

defmodule Jellyfish.Peer.ControlMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof :content, 0

  field :authenticated, 1, type: Jellyfish.Peer.ControlMessage.Authenticated, oneof: 0

  field :auth_request, 2,
    type: Jellyfish.Peer.ControlMessage.AuthRequest,
    json_name: "authRequest",
    oneof: 0

  field :media_event, 3,
    type: Jellyfish.Peer.ControlMessage.MediaEvent,
    json_name: "mediaEvent",
    oneof: 0
end
