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

ARG MIX_ENV=prod
ENV MIX_ENV=$MIX_ENV

# The order of the following commands is important.
# It ensures that:
# * any changes in the `lib` directory will only trigger
# fishjam compilation
# * any changes in the `config` directory will
# trigger both fishjam and deps compilation
# but not deps fetching
# * any changes in the `config/runtime.exs` won't trigger 
# anything
# * any changes in rel directory should only trigger
# making a new release
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY lib lib
RUN mix compile

COPY config/runtime.exs config/

COPY rel rel

RUN mix release

FROM alpine:3.17 AS app

ARG MIX_ENV=prod
ENV MIX_ENV=$MIX_ENV

ARG FJ_GIT_COMMIT
ENV FJ_GIT_COMMIT=$FJ_GIT_COMMIT

RUN addgroup -S fishjam && adduser -S fishjam -G fishjam

# We run the whole image as root, fix permissions in
# the docker-entrypoint.sh and then use gosu to step-down
# from the root.
# See redis docker image for the reference
# https://github.com/docker-library/redis/blob/master/7.0/Dockerfile#L6
ENV GOSU_VERSION 1.16
RUN set -eux; \
  \
  apk add --no-cache --virtual .gosu-deps \
  ca-certificates \
  dpkg \
  gnupg \
  ; \
  \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
  \
  # verify the signature
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  command -v gpgconf && gpgconf --kill all || :; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  \
  # clean up fetch dependencies
  apk del --no-network .gosu-deps; \
  \
  chmod +x /usr/local/bin/gosu; \
  # verify that the binary works
  gosu --version; \
  gosu nobody true

RUN \
  apk add --no-cache \
  openssl1.1-compat \
  libsrtp \
  ffmpeg \
  fdk-aac \
  opus \
  curl \
  ncurses \
  mesa \
  mesa-dri-gallium \
  mesa-dev

WORKDIR /app

# base path where fishjam media files are stored
ENV FJ_RESOURCES_BASE_PATH=./fishjam_resources

# override default (127, 0, 0, 1) IP by 0.0.0.0 
# as docker doesn't allow for connections outside the
# container when we listen to 127.0.0.1
ENV FJ_IP=0.0.0.0
ENV FJ_METRICS_IP=0.0.0.0

ENV FJ_DIST_MIN_PORT=9000
ENV FJ_DIST_MAX_PORT=9000

RUN mkdir ${FJ_RESOURCES_BASE_PATH} && chown fishjam:fishjam ${FJ_RESOURCES_BASE_PATH}

# Create directory for File Component sources
RUN mkdir ${FJ_RESOURCES_BASE_PATH}/file_component_sources \
 && chown fishjam:fishjam ${FJ_RESOURCES_BASE_PATH}/file_component_sources

COPY --from=build /app/_build/${MIX_ENV}/rel/fishjam ./

COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh

ENV HOME=/app

HEALTHCHECK CMD curl --fail -H "authorization: Bearer ${FJ_SERVER_API_TOKEN}" http://localhost:${FJ_PORT:-8080}/health || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["bin/fishjam", "start"]
