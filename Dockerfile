FROM elixir:1.14.3-alpine as build

RUN \
  apk add --no-cache \
  build-base \
  git \
  openssl1.1-compat-dev \
  libsrtp-dev \
  ffmpeg-dev \
  fdk-aac-dev \
  opus-dev \
  rust \
  cargo

WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config
COPY lib lib

RUN mix deps.get
RUN mix deps.compile

RUN mix do compile, release

FROM alpine:3.17 AS app

RUN \
  apk add --no-cache \
  openssl1.1-compat \
  libsrtp \
  ffmpeg \
  fdk-aac \
  opus \
  curl

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/jellyfish ./

ENV HOME=/app

EXPOSE 4000

HEALTHCHECK CMD curl --fail http://localhost:4000 || exit 1

CMD ["bin/jellyfish", "start"]

