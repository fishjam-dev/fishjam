defmodule JellyfishWeb.HLSController do
  use JellyfishWeb, :controller

  alias Jellyfish.Component.HLS.Helpers
  alias Phoenix.PubSub
  alias Plug.Conn

  @ets_key :partial_segments

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
        }
      ) do
    segment = String.to_integer(segment)
    partial = String.to_integer(partial)

    handle_playlist_partial_request(conn, room_id, filename, segment, partial)
  end

  def index(conn, %{"filename" => filename} = params) do
    cond do
      filename == "index.m3u8" ->
        handle_other_file_request(conn, params)

      String.match?(filename, ~r/\.m3u8$/) ->
        handle_playlist_request(conn, params)

      String.match?(filename, ~r/\.m4s$/) ->
        handle_partial_segment_request(conn, params)

      true ->
        handle_other_file_request(conn, params)
    end
  end

  defp handle_partial_segment_request(
         conn,
         %{"room_id" => room_id, "filename" => segment_filename}
       ) do
    {offset, length} = conn |> get_req_header("range") |> Helpers.parse_bytes_range()

    case await_partial_segment(room_id, segment_filename, offset) do
      {:file, path} ->
        conn |> Conn.send_file(200, path, offset, length)

      {:ets, content} ->
        conn |> Conn.send_resp(200, content)
    end
  end

  defp handle_playlist_request(conn, %{"room_id" => room_id, "filename" => filename}) do
    path = Helpers.hls_output_path(room_id, filename)

    if File.exists?(path) do
      send_playlist(conn, path)
    else
      conn |> Conn.send_resp(404, "File not found")
    end
  end

  defp handle_playlist_partial_request(
         conn,
         room_id,
         filename,
         segment,
         partial
       ) do
    PubSub.subscribe(Jellyfish.PubSub, filename)
    await_manifest_update(room_id, filename, segment, partial)
    PubSub.unsubscribe(Jellyfish.PubSub, filename)

    path = Helpers.hls_output_path(room_id, filename)
    send_playlist(conn, path)
  end

  defp handle_other_file_request(conn, %{"room_id" => room_id, "filename" => filename}) do
    path = Helpers.hls_output_path(room_id, filename)

    if File.exists?(path) do
      conn |> Conn.send_file(200, path)
    else
      conn |> Conn.send_resp(404, "File not found")
    end
  end

  defp partial_present_in_manifest?(room_id, filename, target_segment, target_partial) do
    {_segment_filename, segment, partial} =
      Helpers.hls_output_path(room_id, filename)
      |> Helpers.read_manifest()
      |> Helpers.get_last_partial()

    (segment == target_segment and partial >= target_partial) or segment > target_segment
  end

  defp await_manifest_update(room_id, filename, target_segment, target_partial) do
    if partial_present_in_manifest?(room_id, filename, target_segment, target_partial) do
      :ok
    else
      receive do
        {:manifest_update_partial, segment, partial}
        when (segment == target_segment and partial >= target_partial) or segment > target_segment ->
          :ok
      end
    end
  end

  defp await_partial_segment(room_id, segment_filename, offset) do
    case find_partial_in_ets("#{segment_filename}_#{offset}") do
      [{_key, content}] ->
        {:ets, content}

      [] ->
        {:file, Helpers.hls_output_path(room_id, segment_filename)}
    end
  end

  defp send_playlist(conn, path) do
    if conn |> get_req_header("user-agent") |> is_ios_user?() do
      path
      |> get_non_ll_hls_playlist()
      |> then(&Conn.send_resp(conn, 200, &1))
    else
      conn |> Conn.send_file(200, path)
    end
  end

  defp is_ios_user?([]), do: false

  defp is_ios_user?([user_agent]), do: String.contains?(user_agent, "iPhone OS")

  defp get_non_ll_hls_playlist(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(fn line ->
      Enum.all?(Helpers.ll_hls_tags(), fn tag -> not String.contains?(line, tag) end)
    end)
    |> Enum.join("\n")
  end

  defp find_partial_in_ets(partial) do
    :ets.lookup(@ets_key, partial)
  end
end
