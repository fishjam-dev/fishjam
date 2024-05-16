defmodule Fishjam.ResourceManagerTest do
  use FishjamWeb.ComponentCase, async: true

  alias Fishjam.Component.Recording
  alias Fishjam.ResourceManager

  @hour 3_600

  setup do
    base_path = Recording.get_base_path()
    {:ok, pid} = ResourceManager.start(%{interval: 1, recording_timeout: @hour})

    on_exit(fn -> Process.exit(pid, :force) end)

    %{base_path: base_path}
  end

  test "room directory removal", %{room_id: room_id, base_path: base_path} do
    case_1 = Path.join([base_path, room_id])
    case_2 = Path.join([base_path, "not_existing_room_1"])
    case_3 = Path.join([base_path, "not_existing_room_2", "part_1"])

    File.mkdir_p!(case_1)
    File.mkdir_p!(case_2)
    File.mkdir_p!(case_3)

    case_3 |> Path.join("report.json") |> File.touch()

    # Wait double the interval
    Process.sleep(2_000)

    # doesn't remove recordings if room exists
    assert {:ok, []} = File.ls(case_1)

    # removes empty recordings if room doesn't exists
    assert {:error, :enoent} = File.ls(case_2)

    # doesn't remove recordings including parts
    assert {:ok, _} = File.ls(case_3)

    clean_recordings([
      room_id,
      "not_existing_room_1",
      "not_existing_room_2"
    ])
  end

  test "recording part directory removal", %{room_id: room_id, base_path: base_path} do
    case_1 = Path.join([base_path, room_id, "part_1"])
    case_2 = Path.join([base_path, "not_existing_room_4", "part_1"])

    File.mkdir_p!(case_1)
    File.mkdir_p!(case_2)

    # Wait double the interval
    Process.sleep(2_000)

    # doesn't remove empty part if room exists
    assert {:ok, []} = File.ls(case_1)

    # removes empty part if room doesn't exists
    assert {:error, :enoent} = File.ls(case_2)

    clean_recordings([room_id, "not_existing_room_4"])
  end

  test "recording files removal", %{room_id: room_id, base_path: base_path} do
    case_1 = Path.join([base_path, room_id, "part_1"])
    case_2 = Path.join([base_path, "not_existing_room_5", "part_1"])
    case_3 = Path.join([base_path, "not_existing_room_5", "part_2"])

    File.mkdir_p!(case_1)
    File.mkdir_p!(case_2)
    File.mkdir_p!(case_3)

    # modify creation time
    case_1 |> Path.join("report.json") |> File.touch!(System.os_time(:second) - 2 * @hour)
    case_2 |> Path.join("report.json") |> File.touch!(System.os_time(:second) - 2 * @hour)
    case_3 |> Path.join("report.json") |> File.touch!(System.os_time(:second))

    # Wait double the interval
    Process.sleep(2_000)

    # doesn't remove recording if room exists
    assert {:ok, ["report.json"]} = File.ls(case_1)

    # removes recording if exceeds timeout and room doesn't exist
    assert {:error, :enoent} = File.ls(case_2)

    # doesn't remove recording if doesn't exceed timeout
    assert {:ok, ["report.json"]} = File.ls(case_3)

    clean_recordings([room_id, "not_existing_room_5"])
  end

  defp clean_recordings(dirs) do
    Enum.each(dirs, fn dir -> Recording.get_base_path() |> Path.join(dir) |> File.rm_rf!() end)
  end
end
