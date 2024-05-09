defmodule JellyfishWeb.DialControllerTest do
  use JellyfishWeb.ConnCase

  @source_uri "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"

  @sip_registrar_credentials %{
    address: "my-sip-registrar.net",
    username: "user-name",
    password: "pass-word"
  }

  setup_all do
    Application.put_env(:jellyfish, :sip_config, sip_external_ip: "127.0.0.1")
    Application.put_env(:jellyfish, :component_used?, sip: true, rtsp: true)

    on_exit(fn ->
      Application.put_env(:jellyfish, :sip_config, sip_external_ip: nil)
      Application.put_env(:jellyfish, :component_used?, sip: false, rtsp: false)
    end)
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)
    conn = put_req_header(conn, "accept", "application/json")

    conn = post(conn, ~p"/room", videoCodec: "h264")
    assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

    on_exit(fn ->
      conn = delete(conn, ~p"/room/#{id}")
      assert response(conn, :no_content)
    end)

    {:ok, %{conn: conn, room_id: id}}
  end

  describe "dial" do
    test "returns error when room doesn't exist", %{conn: conn} do
      conn = post(conn, ~p"/sip/invalid_room_id/component_id/call", phoneNumber: "+123456")
      assert json_response(conn, :not_found)["errors"] == "Room invalid_room_id does not exist"
    end

    test "returns error when sip component doesn't exist", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/sip/#{room_id}/invalid_component_id/call", phoneNumber: "+123456")

      assert json_response(conn, :bad_request)["errors"] ==
               "Component invalid_component_id does not exist"
    end

    test "returns error when sip component doesn't exist with this id", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "rtsp",
          options: %{sourceUri: @source_uri}
        )

      assert %{
               "data" => %{
                 "id" => component_id,
                 "type" => "rtsp"
               }
             } = json_response(conn, :created)

      conn = post(conn, ~p"/sip/#{room_id}/#{component_id}/call", phoneNumber: "+123456")

      assert json_response(conn, :bad_request)["errors"] ==
               "Component #{component_id} is not a SIP component"
    end

    test "return success for proper dial", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "sip",
          options: %{registrarCredentials: @sip_registrar_credentials}
        )

      assert %{
               "data" => %{
                 "id" => component_id,
                 "type" => "sip"
               }
             } = json_response(conn, :created)

      conn = post(conn, ~p"/sip/#{room_id}/#{component_id}/call", phoneNumber: "+123456")

      assert response(conn, :created) ==
               "Successfully schedule calling phone_number: +123456"
    end

    test "return success for proper end_call", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "sip",
          options: %{registrarCredentials: @sip_registrar_credentials}
        )

      assert %{
               "data" => %{
                 "id" => component_id,
                 "type" => "sip"
               }
             } = json_response(conn, :created)

      conn = post(conn, ~p"/sip/#{room_id}/#{component_id}/call", phoneNumber: "+123456")

      assert response(conn, :created) ==
               "Successfully schedule calling phone_number: +123456"

      conn = delete(conn, ~p"/sip/#{room_id}/#{component_id}/call")

      assert response(conn, :no_content)
    end
  end
end
