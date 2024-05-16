Application.put_env(:fishjam, :media_files_path, "tmp/fishjam_resources/")

Mox.defmock(ExAws.Request.HttpMock, for: ExAws.Request.HttpClient)

ExUnit.configure(exclude: [:asterisk])

ExUnit.start(capture_log: true)
