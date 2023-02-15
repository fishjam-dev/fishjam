FROM elixir:1.14.3-alpine as build

RUN \
  apk add --no-cache \
  build-base \
  git \
  openssl-dev \
  libsrtp-dev \
  ffmpeg-dev \
  fdk-aac-dev \
  opus-dev

ARG VERSION
ENV VERISON=${VERSION}

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

FROM alpine:3.16 AS app

# there's possibility that some of the deps are unnecessary
RUN \
  apk add --no-cache \
  ncurses-libs \
  openssl \
  libsrtp \
  ffmpeg \
  fdk-aac \
  opus \
  clang \
  curl

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/jellyfish ./

ENV HOME=/app

EXPOSE 4000

HEALTHCHECK CMD curl --fail http://localhost:4000 || exit 1

CMD ["bin/jellyfish", "start"]
