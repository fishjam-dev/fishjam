defmodule Jellyfish.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(opts :: map()) ::
              {:ok, Membrane.ChildrenSpec.child_definition()} | {:error, term()}
end
