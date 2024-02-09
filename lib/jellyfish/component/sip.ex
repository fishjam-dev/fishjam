defmodule Jellyfish.Component.SIP do
  @moduledoc """
  Module representing the SIP component.
  """

  @behaviour Jellyfish.Endpoint.Config
  @behaviour Jellyfish.Component

  alias Membrane.RTC.Engine.Endpoint.SIP
  alias Membrane.RTC.Engine.Endpoint.SIP.RegistrarCredentials

  alias JellyfishWeb.ApiSpec.Component.SIP.Options

  @type properties :: %{
          credentials: %{
            address: String.t(),
            username: String.t(),
            password: String.t()
          }
        }

  @impl true
  def config(%{engine_pid: engine} = options) do
    sip_config = Application.fetch_env!(:jellyfish, :sip_config)

    cond do
      not sip_config[:sip_used?] ->
        raise """
        SIP components can only be used if JF_SIP_USED environmental variable is set to \"true\"
        """

      is_nil(sip_config[:sip_external_ip]) ->
        raise """
        SIP components can only be used if JF_SIP_IP environmental variable is set
        """

      true ->
        nil
    end

    external_ip = Application.fetch_env!(:jellyfish, :sip_config)[:sip_external_ip]

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, Options.schema()) do
      endpoint_spec =
        Map.from_struct(valid_opts)
        # OpenApiSpex will remove invalid options, so the following conversion, while ugly, is memory-safe
        |> Map.new(fn {k, v} ->
          {Atom.to_string(k) |> Macro.underscore() |> String.to_atom(), v}
        end)
        |> Map.put(:rtc_engine, engine)
        |> Map.put(:external_ip, external_ip)
        |> Map.update!(:registrar_credentials, fn credentials ->
          credentials
          |> Map.to_list()
          |> Keyword.new()
          |> RegistrarCredentials.new()
        end)
        |> then(&struct(SIP, &1))

      properties = valid_opts |> Map.from_struct()

      {:ok, %{endpoint: endpoint_spec, properties: properties}}
    else
      {:error, [%OpenApiSpex.Cast.Error{reason: :missing_field, name: name}]} ->
        {:error, {:missing_parameter, name}}

      {:error, _reason} = error ->
        error
    end
  end

  @impl true
  def after_init(_room_state, _component, _component_options), do: :ok

  @impl true
  def on_remove(_room_state, _component), do: :ok

  @impl true
  def parse_properties(component) do
    component.properties
  end
end
