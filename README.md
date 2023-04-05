# Jellyfish

[![codecov](https://codecov.io/gh/jellyfish-dev/jellyfish/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/jellyfish-dev/jellyfish)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/jellyfish.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/jellyfish)

## Usage

### Running with Docker

To download Jellyfish Docker image, see [Jellyfish images](https://github.com/jellyfish-dev/jellyfish/pkgs/container/jellyfish).

You can also build the image locally

```console
docker  build -t jellyfish .
```

After obtaining the image, you need to find `INTEGRATED_TURN_IP`, it is the IPv4 address at which your computer is accessible in the
network (e.g. private address in a local network, like 192.168.X.X) or a loopback address (i.e. 127.0.0.1), if you want the server to be 
accessible only from your machine. Then the container can be started.

Explicit port exposure (macOS compatible)

```console
docker run -p 50000-50050:50000-50050/udp -p 4000:4000/tcp -e INTEGRATED_TURN_PORT_RANGE=50000-50050 -e INTEGRATED_TURN_IP=<IPv4 address> -e VIRTUAL_HOST=localhost -e SECRET_KEY_BASE=secret ghcr.io/jellyfish-dev/jellyfish:latest
```

Make sure that the exposed UDP ports match `INTEGRATED_TURN_PORT_RANGE`.

Using host network (Linux only)

```console
docker run --network=host -e INTEGRATED_TURN_IP=<IPv4 address> -e VIRTUAL_HOST=localhost -e SECRET_KEY_BASE ghcr.io/jellyfish-dev/jellyfish:latest
```

Instead of passing environmental variables manually you can do

```console
docker run --network=host --env-file ./env-file ghcr.io/jellyfish-dev/jellyfish:latest
```

where `./env-file` is a file containing environmental variables that the image expects, see example file `.env.sample`.

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)
