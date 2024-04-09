defmodule Jellyfish.ResourceManagerTest do
  use ExUnit.Case, async: true

  alias Jellyfish.Component.Recording
  alias Jellyfish.ResourceManager

  @hour 3_600

  setup do
    recording_path = Recording.get_base_path() |> Path.join(UUID.uuid1())
    report_path = Path.join(recording_path, "report.json")

    File.mkdir_p!(recording_path)

    # modify creation time to be one hour ago
    File.touch!(report_path, System.os_time(:second) - @hour)

    on_exit(fn -> File.rm_rf(recording_path) end)

    %{report_path: report_path}
  end

  test "removes a recording that exceeds the timeout", %{report_path: report_path} do
    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 1})

    # Wait double the interval
    Process.sleep(2_000)

    assert {:error, :enoent} = File.read(report_path)
  end

  test "Doesn't remove a recording that not exceeds timeout", %{report_path: report_path} do
    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 2 * @hour})

    # Wait double the interval
    Process.sleep(2_000)

    assert {:ok, ""} = File.read(report_path)
  end
end
