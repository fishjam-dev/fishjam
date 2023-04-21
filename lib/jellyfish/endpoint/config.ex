defmodule Jellyfish.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(map()) :: {:ok, Membrane.ChildrenSpec.child_definition_t()} | {:error, term()}
end
