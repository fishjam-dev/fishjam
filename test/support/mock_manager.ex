defmodule MockManager do
  @moduledoc false

  import Mox

  def http_mock_expect(n, status_code: status_code) do
    expect(ExAws.Request.HttpMock, :request, n, fn _method,
                                                   _url,
                                                   _req_body,
                                                   _headers,
                                                   _http_opts ->
      {:ok, %{status_code: status_code}}
    end)
  end

  def http_mock_stub(status_code: status_code) do
    stub(ExAws.Request.HttpMock, :request, fn _method, _url, _req_body, _headers, _http_opts ->
      {:ok, %{status_code: status_code, body: %{}}}
    end)
  end

  def start_mock_engine(),
    do:
      spawn(fn ->
        receive do
          :stop -> nil
        end
      end)

  def kill_mock_engine(pid), do: send(pid, :stop)
end
