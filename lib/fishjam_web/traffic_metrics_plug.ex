defmodule FishjamWeb.TrafficMetricsPlug do
  @moduledoc false

  import Plug.Conn

  # Assuming additional 14 bytes per request, e.g.
  #    V     VVVVVVVVVV V            V V
  # GET /room HTTP/1.1\r\n   [...]   \r\n
  @request_add 14

  # Assuming additional 19 bytes per response, e.g.
  # VVVVVVVVVVVVVVVV V            V V
  # HTTP/1.1 200 OK\r\n   [...]   \r\n
  #
  # plus ~60 bytes in headers added down the line (e.g. by Cowboy)
  @response_add 19 + 60

  # Assuming additional 4 bytes per each already parsed header, e.g.
  #           VV          V V
  # Connection: keep-alive\r\n
  @header_add 4

  def init(_opts), do: nil

  def call(conn, _opts) do
    :telemetry.execute(
      [:fishjam_web, :request],
      %{bytes: request_size(conn)}
    )

    register_before_send(conn, fn conn ->
      :telemetry.execute(
        [:fishjam_web, :response],
        %{bytes: response_size(conn)}
      )

      conn
    end)
  end

  defp request_size(conn) do
    byte_size(conn.method) + byte_size(conn.request_path) + byte_size(conn.query_string) +
      headers_size(conn.req_headers) + @request_add
  end

  defp response_size(conn) do
    :erlang.iolist_size(conn.resp_body || "") + headers_size(conn.resp_headers) + @response_add
  end

  defp headers_size(headers) do
    Enum.reduce(headers, 0, fn {k, v}, acc ->
      acc + byte_size(k) + byte_size(v) + @header_add
    end)
  end
end
