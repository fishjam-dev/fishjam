defmodule Jellyfish.ComponentTest do
  use ExUnit.Case, async: true

  alias Jellyfish.Component

  test "component gets created only when allowed" do
    options = %{
      sourceUri: "rtsp://abcdefghijkl-12345678.org:23456/aaa/bbb/ccc",
      engine_pid: self()
    }

    Application.put_env(:jellyfish, :component_used?, rtsp: true)
    {:ok, _component} = Component.new(Component.RTSP, options)

    Application.put_env(:jellyfish, :component_used?, rtsp: false)
    assert_raise RuntimeError, fn -> Component.new(Component.RTSP, options) end
  end
end
