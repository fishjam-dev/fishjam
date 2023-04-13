# Jellyfish

[![codecov](https://codecov.io/gh/jellyfish-dev/jellyfish/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/jellyfish-dev/jellyfish)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/jellyfish.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/jellyfish)

Jellyfish is an open-source, general-purpose media server that ships with support for multiple media protocols.
It can be thought of as a multimedia bridge meant for creating different types of multimedia systems that lets 
you easily create a real-time video conferencing system, a broadcasting solution or both at the same time.

It leverages the [Membrane RTC Engine](https://github.com/jellyfish-dev/membrane_rtc_engine), a real-time communication engine/SFU library built with [Membrane](https://membrane.stream/).

## Quickstart

Here we will show you how to set up basic WebRTC server:

Pull and run Jellyfish Docker image:

**MacOS**

```console
docker run -p 50000-50050:50000-50050/udp \
           -p 4000:4000/tcp \
           -e WEBRTC_USED=true \
           -e INTEGRATED_TURN_PORT_RANGE=50000-50050 \
           -e INTEGRATED_TURN_IP=192.168.0.1 \
           -e TOKEN=token \
           -e VIRTUAL_HOST=localhost \
           -e SECRET_KEY_BASE=secret \
           ghcr.io/jellyfish-dev/jellyfish:latest
```

**Linux**

```console
docker run --network=host \
           -e WEBRTC_USED=true \
           -e INTEGRATED_TURN_IP=192.168.0.1 \
           -e TOKEN=token \
           -e VIRTUAL_HOST=localhost \
           -e SECRET_KEY_BASE=secret \
           ghcr.io/jellyfish-dev/jellyfish:latest
```

To learn more about specific options and environmental variables refer to [WebRTC peer documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/peers/webrtc).

Next, setup room and add peer to it. To learn about rooms or peers, go to [Basic Concepts page](https://jellyfish-dev.github.io/jellyfish-docs/introduction/basic_concepts) in Jellyfish docs.
To do that, you can use server SDK, here we will use the [Elixir Server SDK](https://github.com/jellyfish-dev/server_sdk_elixir):

```elixir
client = Jellyfish.Client.new("http://your-jellyfish-server-address.com", "token")

# Create room
{:ok, %Jellyfish.Room{id: room_id}} = Jellyfish.Room.create(client)

# Add peer
{:ok, _peer, peer_token} = Jellyfish.Room.add_peer(client, room_id, "webrtc")
```

You may have noticed the `"token"` argument passed to `Jellyfish.Room.create` function. It is the same token as the one passed to `docker run` command
as a environmental variable `TOKEN`. To learn more about authentication, go to [Authentication page](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/authentication) in Jellyfish docs.

The `peer_token` is a token that will be used by the peer application (e.g. the user that wants to join the videoconferencing room) to open the connection to your Jellyfish instance.
You are responsible for passing it to the peer. Then, you might want to use one of the client SDKs, here we will use the [Typescript client](https://github.com/jellyfish-dev/ts-client-sdk):

```typescript
import { JellyfishClient } from "@jellyfish-dev/ts-client-sdk";
import { MembraneWebRTC } from "@jellyfish-dev/membrane-webrtc-js";

const SCREEN_SHARING_MEDIA_CONSTRAINTS = {
  video: {
    frameRate: { ideal: 20, max: 25 },
    width: { max: 1920, ideal: 1920 },
    height: { max: 1080, ideal: 1080 },
  },
};

// Example metadata types for peer and track
// You can define your own metadata types just make sure they are serializable
type PeerMetadata = {
  name: string;
};

type TrackMetadata = {
  type: "camera" | "screen";
};

// Creates a new JellyfishClient object to interact with Jellyfish
const client = new JellyfishClient<PeerMetadata, TrackMetadata>();

// Start the peer connection
client.connect({
  peerMetadata: { name: "peer" },
  isSimulcastOn: false,
  token: peerToken,  // this is the peer_token from previous server SDK snippet
});
```

To learn how to define some useful callbacks, see the [minimal Typescript client example](https://github.com/jellyfish-dev/ts-client-sdk/tree/main/examples/minimal).

Congratulations! You have succesfully set up the the core elements needed to get Jellyfish running.

# Documentation

Everything you need to get started with Jellyfish is available in the [Jellyfish docs](https://jellyfish-dev.github.io/jellyfish-docs/).

You can read about theoretical concepts and problems we encountered in [Jellybook](https://jellyfish-dev.github.io/book/).

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)
