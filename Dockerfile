FROM elixir:1.14.3-otp-24-alpine as build

RUN \
  apk add --no-cache \
  build-base \
  git \
  openssl1.1-compat-dev \
  libsrtp-dev \
  ffmpeg-dev \
  fdk-aac-dev \
  opus-dev \
  curl

WORKDIR /app

ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

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

