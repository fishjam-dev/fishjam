defmodule JellyfishWeb.HLSController do
  use JellyfishWeb, :controller

  require Logger
  alias Jellyfish.Component.HLS.RequestHandler
  alias Plug.Conn

  @hls_directory "jellyfish_output/hls_output"

  def index(
        conn,
        %{
          "_HLS_skip" => _skip
        } = params
      ) do
    params
    |> Map.update!("filename", &String.replace(&1, ".m3u8", "_delta.m3u8"))
    |> Map.delete("_HLS_skip")
    |> then(&index(conn, &1))
  end

  def index(
        conn,
        %{
          "room_id" => room_id,
          "filename" => filename,
          "_HLS_msn" => segment,
          "_HLS_part" => part
        }
      ) do
    partial = {String.to_integer(segment), String.to_integer(part)}

    result =
      if String.contains?(filename, "_delta.m3u8") do
        RequestHandler.handle_delta_manifest_request(room_id, partial)
      else
        RequestHandler.handle_manifest_request(room_id, partial)
      end

    case result do
      {:ok, manifest} ->
        Conn.send_resp(conn, 200, manifest)

      {:error, reason} ->
        Logger.error("Error handling manifest request, reason: #{reason}")
        Conn.send_resp(conn, 400, "Not found")
    end
  end

  def index(conn, %{"room_id" => room_id, "filename" => filename}) do
    range =
      conn
      |> get_req_header("range")
      |> parse_bytes_range()

    if String.match?(filename, ~r/\.m4s$/) and range != :not_partial do
      {offset, _lenght} = range
      {:ok, partial_segment} = RequestHandler.handle_partial_request(room_id, filename, offset)
      Conn.send_resp(conn, 200, partial_segment)
    else
      file_path = Path.join([@hls_directory, room_id, filename])
      Conn.send_file(conn, 200, file_path)
    end
  end

  def parse_bytes_range(raw_range) do
    case raw_range do
      [] ->
        :not_partial

      [raw_range] ->
        "bytes=" <> range = raw_range
        [first, last] = range |> String.split("-") |> Enum.map(&String.to_integer(&1))
        {first, last - first + 1}
    end
  end
end
