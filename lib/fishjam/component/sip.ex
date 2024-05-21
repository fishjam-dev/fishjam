defmodule Fishjam.Component.SIP do
  @moduledoc """
  Module representing the SIP component.
  """

  @behaviour Fishjam.Endpoint.Config
  use Fishjam.Component

  alias Membrane.RTC.Engine.Endpoint.SIP
  alias Membrane.RTC.Engine.Endpoint.SIP.RegistrarCredentials

  alias FishjamWeb.ApiSpec.Component.SIP.Options

  @type properties :: %{
          registrar_credentials: %{
            address: String.t(),
            username: String.t(),
            password: String.t()
          }
        }

  @impl true
  def config(%{engine_pid: engine} = options) do
    external_ip = Application.fetch_env!(:fishjam, :sip_config)[:sip_external_ip]

    with {:ok, serialized_opts} <- serialize_options(options, Options.schema()) do
      endpoint_spec = %SIP{
        rtc_engine: engine,
        external_ip: external_ip,
        registrar_credentials: create_register_credentials(serialized_opts.registrar_credentials)
      }

      properties = serialized_opts

      {:ok, %{endpoint: endpoint_spec, properties: properties}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name} | _rest]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end

  defp create_register_credentials(credentials) do
    credentials
    |> Map.to_list()
    |> Keyword.new()
    |> RegistrarCredentials.new()
  end
end
