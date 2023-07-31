defmodule Jellyfish.Component.HLS.Helpers do
  @moduledoc false

  @spec hls_output_path(prefix :: String.t()) :: String.t()
  def hls_output_path(prefix) do
    Path.join([hls_output_mount_path(), "hls_output", prefix])
    # [hls_output_mount_path(), "hls_output", prefix] |> Path.join()
  end

  @spec hls_output_path(prefix :: String.t(), filename :: String.t()) :: String.t()
  def hls_output_path(prefix, filename) do
    Path.join([hls_output_mount_path(), "hls_output", prefix, filename])
    # [hls_output_mount_path(), prefix, filename] |> Path.join()
  end

  @spec ll_hls_tags :: [binary]
  def ll_hls_tags() do
    """
    #EXT-X-SERVER-CONTROL
    #EXT-X-PART-INF
    #EXT-X-PART
    #EXT-X-PRELOAD-HINT
    #EXT-X-RENDITION-REPORT
    #EXT-X-SKIP
    """
    |> String.trim()
    |> String.split("\n")
  end

  @spec hls_output_mount_path() :: String.t()
  def hls_output_mount_path(),
    do: Application.fetch_env!(:jellyfish, :output_base_path)

  @spec parse_filename(binary) :: {integer, binary}
  def parse_filename(segment_filename) do
    [_type, "segment", segment, manifest_name] =
      segment_filename
      |> String.replace(".m4s", "")
      |> String.split("_")

    {String.to_integer(segment), manifest_name}
  end

  @spec read_manifest(binary) :: binary
  def read_manifest(manifest_path) do
    case File.read(manifest_path) do
      {:ok, binary} -> binary
      {:error, _err} -> ""
    end
  end

  @spec get_last_partial(binary) ::
          {binary, non_neg_integer, non_neg_integer} | {:error, :no_partial_segments}
  def get_last_partial(binary) do
    partial_tags =
      binary
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "#EXT-X-PART:"))
      |> Enum.reverse()

    if Enum.empty?(partial_tags) do
      {:error, :no_partial_segments}
    else
      last_partial = hd(partial_tags)
      segment_filename = find_partial_tag(last_partial, "URI")
      {segment_number, _manifest_name} = parse_filename(last_partial)

      partial_count =
        Enum.count(partial_tags, &String.contains?(&1, "_segment_#{segment_number}_"))

      {segment_filename, segment_number, partial_count - 1}
    end
  end

  @spec parse_bytes_range([binary]) :: {number, :all | number}
  def parse_bytes_range(raw_range) do
    case raw_range do
      [] ->
        {0, :all}

      [raw_range] ->
        "bytes=" <> range = raw_range
        [first, last] = range |> String.split("-") |> Enum.map(&String.to_integer(&1))
        {first, last - first + 1}
    end
  end

  defp find_partial_tag(partial, tag) do
    partial
    |> String.split(",")
    |> Enum.find(&String.contains?(&1, "#{tag}="))
    |> String.replace("#{tag}=", "")
    |> String.replace("\"", "")
  end
end
