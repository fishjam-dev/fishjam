Application.put_env(:jellyfish, :output_base_path, "tmp/hls_output/")

ExUnit.start(capture_log: true)
