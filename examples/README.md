# Jellyfish examples

This directory contains example Elixir scripts for the most common Jellyfish use cases,
as well as the instructions necessary to run them.

## RTSP to HLS

### Elixir

1. Start a local instance of Jellyfish (e.g. by running `mix phx.server`)
2. Run `elixir ./rtsp_to_hls.exs "rtsp://your-rtsp-stream-source:port/stream"`

### Python

1. Install the Jellyfish Python Server SDK: `pip install jellyfish-server-sdk`
2. Start a local instance of Jellyfish (e.g. by running `mix phx.server`)
3. Run `python3 ./rtsp_to_hls.py "rtsp://your-rtsp-stream-source:port/stream"`
