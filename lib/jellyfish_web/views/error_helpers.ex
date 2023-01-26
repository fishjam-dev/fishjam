defmodule JellyfishWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  @spec translate_error({any, any}) :: any
  @doc """
  Translates an error message.
  """
  def translate_error({msg, opts}) do
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _text -> to_string(value) end)
    end)
  end
end
