defmodule Jellyfish.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(map()) ::
              {:ok,
               %{
                 :endpoint => Membrane.ChildrenSpec.child_definition(),
                 optional(:metadata) => term()
               }}
              | {:error, term()}
end
