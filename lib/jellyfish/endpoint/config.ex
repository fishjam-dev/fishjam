defmodule Jellyfish.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(map) :: Membrane.ParentSpec.child_spec_t()
end
