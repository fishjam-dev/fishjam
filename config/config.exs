import Config

config :membrane_core, :enable_metrics, false

config :fishjam, FishjamWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: FishjamWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fishjam.PubSub,
  live_view: [signing_salt: "/Lo03qJT"]

config :fishjam,
  webrtc_metrics_scrape_interval: 1000,
  room_metrics_scrape_interval: 10

config :membrane_telemetry_metrics, enabled: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :room_id, :peer_id]

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
    [application: :membrane_rtc_engine_sip, level_lower_than: :warning],
    [module: Membrane.SRTP.Encryptor, level_lower_than: :error],
    [module: Membrane.RTCP.Receiver, level_lower_than: :warning]
  ]

config :ex_aws,
  http_client: Fishjam.Component.HLS.HTTPoison,
  normalize_path: false

config :bundlex, :disable_precompiled_os_deps, apps: [:membrane_h264_ffmpeg_plugin, :ex_libsrtp]

import_config "#{config_env()}.exs"
