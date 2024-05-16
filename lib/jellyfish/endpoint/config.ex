defmodule Fishjam.Endpoint.Config do
  @moduledoc """
  An interface for RTC Engine endpoint configuration.
  """

  @callback config(map()) ::
              {:ok,
               %{
                 :endpoint => Membrane.ChildrenSpec.child_definition(),
                 optional(:properties) => term()
               }}
              | {:error, term()}
end
