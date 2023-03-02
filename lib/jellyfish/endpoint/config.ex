defmodule Jellyfish.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(map()) :: Membrane.ChildrenSpec.child_definition_t()
end
