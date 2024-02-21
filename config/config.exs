import Config

config :jellyfish, JellyfishWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: JellyfishWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jellyfish.PubSub,
  live_view: [signing_salt: "/Lo03qJT"]

config :jellyfish,
  webrtc_metrics_scrape_interval: 1000,
  room_metrics_scrape_interval: 10

config :membrane_telemetry_metrics, enabled: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :room_id]

config :logger_json, :backend,
  metadata: [:request_id, :room_id],
  json_encoder: Jason,
  formatter: LoggerJSON.Formatters.BasicLogger

config :phoenix, :json_library, Jason
config :phoenix, :logger, false

config :logger,
  compile_time_purge_matching: [
    [application: :membrane_rtc_engine, level_lower_than: :warning],
    [application: :membrane_rtc_engine_webrtc, level_lower_than: :warning],
    [application: :membrane_rtc_engine_hls, level_lower_than: :warning],
    [application: :membrane_rtc_engine_rtsp, level_lower_than: :warning],
    [application: :membrane_rtc_engine_file, level_lower_than: :warning],
    [application: :membrane_rtc_engine_sip, level_lower_than: :warning]
  ]

config :jellyfish,
  divo: "docker-compose.yaml",
  divo_wait: [dwell: 1_500, max_tries: 50]

config :ex_aws, :http_client, Jellyfish.Component.HLS.HTTPoison

config :bundlex, :disable_precompiled_os_deps, apps: [:membrane_h264_ffmpeg_plugin, :ex_libsrtp]

import_config "#{config_env()}.exs"
