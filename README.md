# Jellyfish

[![codecov](https://codecov.io/gh/jellyfish-dev/jellyfish/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/jellyfish-dev/jellyfish)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/jellyfish.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/jellyfish)

## Usage

### Running in Docker

To download Jellyfish Docker image, see [Jellyfish images](https://github.com/jellyfish-dev/jellyfish/pkgs/container/jellyfish).

You can also build the image locally

```console
docker  build -t jellyfish .
```

To run the Docker container, use

```console
docker run -p 4000:4000 --env-file ./env_file jellyfish
```

Where `./env-file` is a file containing environmental variables that the image expects, see example file `.env.sample`.
Now Jellyfish is running on port 4000.

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)
