defmodule Jellyfish.Component.HLS.ManagerTest do
  @moduledoc false

  use ExUnit.Case

  import Mox

  alias Jellyfish.Component.HLS
  alias Jellyfish.Component.HLS.Manager

  @files ["manifest.m3u8", "header.mp4", "segment_1.m3u8", "segment_2.m3u8"]
  @body <<1, 2, 3, 4>>
  @s3_credentials %{
    access_key_id: "access_key_id",
    secret_access_key: "secret_access_key",
    region: "region",
    bucket: "bucket"
  }

  setup do
    room_id = UUID.uuid4()
    hls_dir = HLS.output_dir(room_id, persistent: false)
    options = %{s3: nil, persistent: true}

    File.mkdir_p!(hls_dir)
    for filename <- @files, do: :ok = hls_dir |> Path.join(filename) |> File.write(@body)

    on_exit(fn -> File.rm_rf!(hls_dir) end)

    {:ok, %{room_id: room_id, hls_dir: hls_dir, options: options}}
  end

  setup :verify_on_exit!
  setup :set_mox_from_context

  test "Spawn manager without credentials", %{
    room_id: room_id,
    hls_dir: hls_dir,
    options: options
  } do
    create_expect(0)
    pid = start_process()

    {:ok, manager} = Manager.start(room_id, pid, hls_dir, options)
    ref = Process.monitor(manager)

    kill_process(pid)

    assert_receive {:DOWN, ^ref, :process, ^manager, :normal}
    assert length(File.ls!(hls_dir)) == 4
  end

  test "Spawn manager with credentials", %{room_id: room_id, hls_dir: hls_dir, options: options} do
    create_expect(4)
    pid = start_process()

    {:ok, manager} = Manager.start(room_id, pid, hls_dir, %{options | s3: @s3_credentials})
    ref = Process.monitor(manager)

    kill_process(pid)

    assert_receive {:DOWN, ^ref, :process, ^manager, :normal}
    assert length(File.ls!(hls_dir)) == 4
  end

  test "Spawn manager with persistent false", %{
    room_id: room_id,
    hls_dir: hls_dir,
    options: options
  } do
    create_expect(0)
    pid = start_process()

    {:ok, manager} = Manager.start(room_id, pid, hls_dir, %{options | persistent: false})
    ref = Process.monitor(manager)

    kill_process(pid)

    assert_receive {:DOWN, ^ref, :process, ^manager, :normal}
    assert {:error, _} = File.ls(hls_dir)
  end

  defp create_expect(n) do
    expect(ExAws.Request.HttpMock, :request, n, fn _method,
                                                   _url,
                                                   _req_body,
                                                   _headers,
                                                   _http_opts ->
      {:ok, %{status_code: 200, headers: %{}}}
    end)
  end

  defp start_process(),
    do:
      spawn(fn ->
        receive do
          :stop -> nil
        end
      end)

  defp kill_process(pid), do: send(pid, :stop)
end
