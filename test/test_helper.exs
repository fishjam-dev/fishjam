Application.put_env(:jellyfish, :media_files_path, "tmp/jellyfish_resources/")

Mox.defmock(ExAws.Request.HttpMock, for: ExAws.Request.HttpClient)

ExUnit.configure(exclude: [:asterisk])

ExUnit.start(capture_log: true)
