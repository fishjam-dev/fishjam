defmodule JellyfishWeb.Component.SIPComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  @sip_credentials %{
    address: "my-sip-registrar.net",
    username: "user-name",
    password: "pass-word"
  }

  @sip_default_properties %{
                            registrarCredentials: map_keys_to_string(@sip_credentials)
                          }
                          |> map_keys_to_string()

  setup_all do
    Application.put_env(:jellyfish, :sip_config, sip_external_ip: "127.0.0.1")
    Application.put_env(:jellyfish, :component_used?, sip: true)

    on_exit(fn ->
      Application.put_env(:jellyfish, :sip_config, sip_external_ip: nil)
      Application.put_env(:jellyfish, :component_used?, sip: false)
    end)
  end

  describe "create SIP component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "sip",
          options: %{registrarCredentials: @sip_credentials}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "sip",
                 "properties" => @sip_default_properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "sip")
    end

    test "renders errors when required options are missing", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "sip")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Required field \"registrarCredentials\" missing"
    end
  end
end
