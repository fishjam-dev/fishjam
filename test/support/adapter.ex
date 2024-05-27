defmodule Fishjam.Adapter do
  @moduledoc false

  @behaviour ExAws.Config.AuthCache.AuthConfigAdapter

  @config %{
    access_key_id: "AKIAIOSFODNN7EXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    region: "us-east-1"
  }

  @impl true
  def adapt_auth_config(_config, _profile, _expiration) do
    @config
  end
end
