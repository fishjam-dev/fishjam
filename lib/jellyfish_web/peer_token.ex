defmodule JellyfishWeb.PeerToken do
  @moduledoc false

  @spec generate(map()) :: nonempty_binary
  def generate(data) do
    Phoenix.Token.sign(
      JellyfishWeb.Endpoint,
      Application.fetch_env!(:jellyfish, :auth_salt),
      data
    )
  end

  @spec verify(binary) :: {:ok, any} | {:error, :expired | :invalid | :missing}
  def verify(token) do
    Phoenix.Token.verify(
      JellyfishWeb.Endpoint,
      Application.get_env(:jellyfish, :auth_salt),
      token,
      max_age: Application.get_env(:jellyfish, :jwt_max_age)
    )
  end
end
