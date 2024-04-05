defmodule Jellyfish.ResourceManagerTest do
  use ExUnit.Case

  alias Jellyfish.Component.Recording
  alias Jellyfish.ResourceManager

  setup do
    recording_path = Recording.get_base_path() |> Path.join("test")
    report_path = Path.join(recording_path, "report.json")

    File.mkdir_p!(recording_path)
    File.touch!(report_path)

    on_exit(fn -> File.rm_rf(recording_path) end)

    %{report_path: report_path}
  end

  test "removes a recording that exceeds the timeout", %{report_path: report_path} do
    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 1})

    # Wait for report to exceed timeout
    Process.sleep(5_000)

    assert {:error, :enoent} = File.read(report_path)
  end

  test "Doesn't remove a recording that not exceeds timeout", %{report_path: report_path} do
    {:ok, _pid} = ResourceManager.start(%{interval: 1, recording_timeout: 10})

    assert {:ok, ""} = File.read(report_path)
  end
end
