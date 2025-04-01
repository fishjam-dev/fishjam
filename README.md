# Moving forward with Fishjam

Fishjam Media Server is evolving into [Fishjam](https://fishjam.io/).

While this organization remains public, we will not be updating it with new developments or fixes.  
If you run your product on Fishjam Media Server and these changes affect your business, please contact us via projects@swmansion.com.

# Fishjam Media Server

[![codecov](https://codecov.io/gh/fishjam-dev/fishjam/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/fishjam-dev/fishjam)
[![CircleCI](https://circleci.com/gh/fishjam-dev/fishjam.svg?style=svg)](https://circleci.com/gh/fishjam-dev/fishjam)

Fishjam is an open-source, general-purpose media server that ships with support for multiple media protocols.
It can be thought of as a multimedia bridge meant for creating different types of multimedia systems that lets 
you easily create a real-time video conferencing system, a broadcasting solution, or both at the same time.

It leverages the [Membrane RTC Engine](https://github.com/fishjam-dev/membrane_rtc_engine), a real-time communication engine/SFU library built with [Membrane](https://membrane.stream/).

## Installation

There are two ways of running Fishjam:
- building from source (requires Elixir and native dependencies)
- using Fishjam Docker images

To learn more, refer to [Installation page](https://fishjam-dev.github.io/fishjam-docs/getting_started/installation) in Fishjam docs.

## SDKs

Fishjam provides server SDKs (used to manage the state of Fishjam server) and client SDKs (used to connect to the Fishjam instance, receive media, etc.).

To get the list of all available SDKs, go to [SDKs page](https://fishjam-dev.github.io/fishjam-docs/getting_started/sdks) in Fishjam docs.

## Examples

- WebRTC Dashboard

    A standalone dashboard that can create rooms, add peers and send media between the peers. Available [here](https://github.com/fishjam-dev/fishjam-dashboard).
To use the dashboard, you need to set up Fishjam with WebRTC, refer to [WebRTC peer page](https://fishjam-dev.github.io/fishjam-docs/getting_started/peers/webrtc) in Fishjam docs to learn how to do that.
Dashboard makes HTTP requests to Fishjam that need to be authorized and requires a token to do so, learn more from [Authentication page](https://fishjam-dev.github.io/fishjam-docs/getting_started/authentication) in Fishjam docs.

## Documentation

Everything you need to get started with Fishjam is available in the [Fishjam docs](https://fishjam-dev.github.io/fishjam-docs/).

You can read about theoretical concepts and problems we encountered in the [Fishjambook](https://fishjam-dev.github.io/book/).

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=fishjam)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=fishjam)

Licensed under the [Apache License, Version 2.0](LICENSE)
