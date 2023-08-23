defmodule JellyfishWeb.HLSController do
  use JellyfishWeb, :controller

  require Logger

  alias Jellyfish.Component.HLS.RequestHandler
  alias Plug.Conn

  def index(
        conn,
        %{
          "_HLS_skip" => _skip
        } = params
      ) do
    params
    |> Map.update!("filename", &String.replace_suffix(&1, ".m3u8", "_delta.m3u8"))
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
      if String.ends_with?(filename, "_delta.m3u8") do
        RequestHandler.handle_delta_manifest_request(room_id, partial)
      else
        RequestHandler.handle_manifest_request(room_id, partial)
      end

    case result do
      {:ok, manifest} ->
        Conn.send_resp(conn, 200, manifest)

      {:error, reason} ->
        Logger.error("Error handling manifest request, reason: #{inspect(reason)}")
        Conn.send_resp(conn, 404, "Not found")
    end
  end

  def index(conn, %{"room_id" => room_id, "filename" => filename}) do
    range =
      conn
      |> get_req_header("range")
      |> parse_bytes_range()

    result =
      if String.ends_with?(filename, ".m4s") and range != :not_partial do
        {offset, _length} = range
        RequestHandler.handle_partial_request(room_id, filename, offset)
      else
        RequestHandler.handle_file_request(room_id, filename)
      end

    case result do
      {:ok, file} ->
        Conn.send_resp(conn, 200, file)

      {:error, _reason} ->
        Conn.send_resp(conn, 404, "Not found")
    end
  end

  @doc """
  Every partial request comes with a byte range which represents where specifically in the file partial is located.
  Example: "bytes=100-200" 100-200, represents the scope in which partial is located in the file.
  """
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
