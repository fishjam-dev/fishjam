defmodule Fishjam.FeatureFlags do
  @moduledoc """
  Module to resolve any feature flags, since we are not using database we can't use fun_with_flags.
  Because of that we base feature flags on the environment variables mainly.
  """

  @doc """
  Flag for disabling custom room names, which will be replaced by the generated based on the node name.

  Introduced: 28/05/2024
  Removal: Once we move on to generated room_ids permanently.
  """
  def custom_room_name_disabled?,
    do: Application.get_env(:fishjam, :feature_flags)[:custom_room_name_disabled] || false
end
