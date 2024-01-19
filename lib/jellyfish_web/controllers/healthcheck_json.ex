defmodule JellyfishWeb.HealthcheckJSON do
  @moduledoc false

  def show(%{status: status}) do
    %{data: %{status: status}}
  end
end
