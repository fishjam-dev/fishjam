# Jellyfish examples

This directory contains example Elixir scripts for the most common Jellyfish use cases,
as well as the instructions necessary to run them.

## RTSP to HLS

1. Start a local instance of Jellyfish (e.g. by running `mix phx.server`)
2. Run `elixir examples/rtsp_to_hls.exs "rtsp://your-rtsp-stream-source:port/stream"`
