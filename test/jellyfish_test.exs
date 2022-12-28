defmodule JellyfishTest do
  use ExUnit.Case
  doctest Jellyfish

  test "greets the world" do
    assert Jellyfish.hello() == :world
  end
end
