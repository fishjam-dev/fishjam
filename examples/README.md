# Jellyfish examples

This directory contains example Elixir scripts for the most common Jellyfish use cases,
as well as the instructions necessary to run them.

## RTSP to HLS

1. Start a local instance of Jellyfish (e.g. by running `mix phx.server`)
2. Open `examples/rtsp_to_hls.exs` with your text editor of choice and replace
   `"PUT_STREAM_URI_HERE"` with the URI of your chosen RTSP stream source
3. Run `elixir examples/rtsp_to_hls.exs`
