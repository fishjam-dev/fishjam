defmodule JellyfishWeb.HLSController do
  use JellyfishWeb, :controller

  alias Plug.Conn
  alias Jellyfish.Component.HLS.Broadcaster

  action_fallback JellyfishWeb.FallbackController

  @spec index(Conn.t(), map) :: Conn.t()
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
        "_HLS_part" => partial
      } = params
    ) do
    segment = String.to_integer(segment)
    partial = String.to_integer(partial)

    manifest = Broadcaster.request_partial_manifest(room_id, filename, segment, partial)

    Conn.send_resp(conn, 200, manifest)
  end

  def index(
    %Conn{req_headers: req_headers} = conn,
    %{
      "room_id" => room_id,
      "filename" => filename
    }
    ) do
    IO.inspect(req_headers, label: "Controller Request")
    if List.keymember?(req_headers, "range", 0) and String.match?(filename, ~r/\.m4s$/) do
      {"range", "bytes=" <> range} = List.keyfind(req_headers, "range", 0)
      partial = Broadcaster.request_partial_segment(room_id, filename, range)
      Conn.send_resp(conn, 200, partial)
    else
      base_path = Application.fetch_env!(:jellyfish, :output_base_path)
      file_path = Path.join([base_path, "hls_output", room_id, filename])
      Conn.send_file(conn, 200, file_path)
    end
  end
end
