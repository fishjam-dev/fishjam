Application.put_env(:jellyfish, :media_files_path, "tmp/jellyfish_media_files/")

Mox.defmock(ExAws.Request.HttpMock, for: ExAws.Request.HttpClient)

ExUnit.start(capture_log: true)
