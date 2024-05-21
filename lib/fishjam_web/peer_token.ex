defmodule FishjamWeb.PeerToken do
  @moduledoc false
  alias FishjamWeb.Endpoint

  @spec generate(map()) :: nonempty_binary
  def generate(data) do
    Phoenix.Token.sign(
      Endpoint,
      Application.fetch_env!(:fishjam, Endpoint)[:secret_key_base],
      data
    )
  end

  @spec verify(binary) :: {:ok, any} | {:error, :expired | :invalid | :missing}
  def verify(token) do
    Phoenix.Token.verify(
      Endpoint,
      Application.fetch_env!(:fishjam, Endpoint)[:secret_key_base],
      token,
      max_age: Application.fetch_env!(:fishjam, :jwt_max_age)
    )
  end
end
