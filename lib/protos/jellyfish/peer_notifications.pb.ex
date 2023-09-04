defmodule Jellyfish.PeerMessage.Authenticated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule Jellyfish.PeerMessage.AuthRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :token, 1, type: :string
end

defmodule Jellyfish.PeerMessage.MediaEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :data, 1, type: :string
end

defmodule Jellyfish.PeerMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  oneof :content, 0

  field :authenticated, 1, type: Jellyfish.PeerMessage.Authenticated, oneof: 0

  field :auth_request, 2,
    type: Jellyfish.PeerMessage.AuthRequest,
    json_name: "authRequest",
    oneof: 0

  field :media_event, 3, type: Jellyfish.PeerMessage.MediaEvent, json_name: "mediaEvent", oneof: 0
end
