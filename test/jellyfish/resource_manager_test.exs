defmodule Jellyfish.ResourceManagerTest do
  use JellyfishWeb.ComponentCase, async: true

  alias Jellyfish.Component.Recording
  alias Jellyfish.ResourceManager

  @hour 3_600

  test "recordings removal", %{room_id: room_id} do
    base_path = Recording.get_base_path()

    case_1 = Path.join([base_path, room_id])
    case_2 = Path.join([base_path, "not_existing_room_1"])
    case_3 = Path.join([base_path, "not_existing_room_2", "part_1"])
    case_4 = Path.join([base_path, "not_existing_room_3", "part_1"])

    File.mkdir_p!(case_1)
    File.mkdir_p!(case_2)
    File.mkdir_p!(case_3)
    File.mkdir_p!(case_4)

    case_4 |> Path.join("report.json") |> File.touch()

    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 10})

    # Wait double the interval
    Process.sleep(2_000)

    # doesn't remove recordings if room exists
    assert {:ok, []} = File.ls(case_1)

    # removes empty recordings if room doesn't exists
    assert {:error, :enoent} = File.ls(case_2)

    # removes recordings if room doesn't exists and part is empty
    assert {:error, :enoent} = File.ls(case_3)

    # doesn't remove recordings if room doesn't exists and part is not empty
    assert {:ok, _} = File.ls(case_4)

    clean_recordings([
      room_id,
      "not_existing_room_1",
      "not_existing_room_2",
      "not_existing_room_3"
    ])
  end

  test "removes a recording that exceeds the timeout", %{room_id: room_id} do
    base_path = Recording.get_base_path()

    case_1 = Path.join([base_path, room_id, "part_1"])
    case_2 = Path.join([base_path, "not_existing_room_4", "part_1"])

    File.mkdir_p!(case_1)
    File.mkdir_p!(case_2)

    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 1})

    # Wait double the interval
    Process.sleep(2_000)

    # doesn't remove empty part if room exists
    assert {:ok, []} = File.ls(case_1)

    # removes empty part if room doesn't exists
    assert {:error, :enoent} = File.ls(case_2)

    clean_recordings([room_id, "not_existing_room_4"])
  end

  test "removes a recording", %{room_id: room_id} do
    base_path = Recording.get_base_path()

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

    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: @hour})

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
