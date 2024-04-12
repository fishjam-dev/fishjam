defmodule Jellyfish.ConfigReaderTest do
  use ExUnit.Case

  alias Jellyfish.Room.{Config, State}

  setup do
    config = Config.from_params(%{})
    State.new("test", config)
  end

  test "" do
  end
end
