# Jellyfish

[![codecov](https://codecov.io/gh/jellyfish-dev/jellyfish/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/jellyfish-dev/jellyfish)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/jellyfish.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/jellyfish)

Jellyfish is an open-source, general-purpose media server that ships with support for multiple media protocols.
It can be thought of as a multimedia bridge meant for creating different types of multimedia systems that lets 
you easily create a real-time video conferencing system, a broadcasting solution, or both at the same time.

It leverages the [Membrane RTC Engine](https://github.com/jellyfish-dev/membrane_rtc_engine), a real-time communication engine/SFU library built with [Membrane](https://membrane.stream/).

## Installation

There are two ways of running Jellyfish:
- building from source (requires Elixir and native dependencies)
- using Jellyfish Docker images

To learn more, refer to [Installation page](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/installation) in Jellyfish docs.

## SDKs

Jellyfish provides server SDKs (used to manage the state of Jellyfish server) and client SDKs (used to connect to the Jellyfish instance, receive media, etc.).

To get the list of all available SDKs, go to [SDKs page](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/sdks) in Jellyfish docs.

## Examples

- WebRTC Dashboard

    A standalone dashboard that can create rooms, add peers and send media between the peers. Available [here](https://github.com/jellyfish-dev/jellyfish-react-client/tree/main/examples/dashboard).
To use the dashboard, you need to set up Jellyfish with WebRTC, refer to [WebRTC peer page](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/peers/webrtc) in Jellyfish docs to learn how to do that.
Dashboard makes HTTP requests to Jellyfish that need to be authorized and requires a token to do so, learn more from [Authentication page](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/authentication) in Jellyfish docs.

## Documentation

Everything you need to get started with Jellyfish is available in the [Jellyfish docs](https://jellyfish-dev.github.io/jellyfish-docs/).

You can read about theoretical concepts and problems we encountered in the [Jellybook](https://jellyfish-dev.github.io/book/).

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)
