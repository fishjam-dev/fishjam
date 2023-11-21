Application.put_env(:jellyfish, :output_base_path, "tmp/hls_output/")

Mox.defmock(ExAws.Request.HttpMock, for: ExAws.Request.HttpClient)

ExUnit.start(capture_log: false)
