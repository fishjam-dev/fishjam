defmodule Fishjam.FeatureFlags do
  @moduledoc """
  Module to resolve any feature flags, since we are not using database we can't use fun_with_flags.
  Because of that we base feature flags on the environment variables mainly.
  """

  @doc """
  Flag for enabling request routing within the cluster of Fishjams.
  When toggled, it disallows setting custom room names - they will instead be generated based on the node name.

  Introduced: 28/05/2024
  Removal: Once we move on to generated room_ids and cluster-wide request routing permanently.
  """
  def request_routing_enabled?(),
    do: Application.get_env(:fishjam, :feature_flags)[:request_routing_enabled?]

  @doc "Info about currently enabled feature flags"
  def info() do
    """
    Feature flags:
      * Request routing: #{status(request_routing_enabled?())}
    """
  end

  defp status(flag), do: if(flag, do: "ENABLED", else: "disabled")
end
