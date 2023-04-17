defmodule JellyfishWeb.ComponentControllerTest do
  use JellyfishWeb.ConnCase

  import OpenApiSpex.TestAssertions

  @schema JellyfishWeb.ApiSpec.spec()

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    room_conn = post(conn, ~p"/room")
    assert %{"id" => id} = json_response(room_conn, :created)["data"]

    on_exit(fn ->
      room_conn = delete(conn, ~p"/room/#{id}")
      assert response(room_conn, :no_content)
    end)

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), room_id: id}}
  end

  describe "create hls component" do
    test "renders component when data is valid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")

      assert response = %{"data" => %{"id" => id}} = json_response(conn, :created)
      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "hls"}
               ]
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when component type is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "invalid_type")

      assert json_response(conn, :bad_request)["errors"] == "Invalid component type"
    end

    test "renders errors when room doesn't exists", %{conn: conn} do
      room_id = "abc"
      conn = post(conn, ~p"/room/#{room_id}/component", type: "hls")
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end

    test "renders errors when request body structure is invalid", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/room/#{room_id}/component", invalid_parameter: "hls")

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "create rtsp component" do
    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "rtsp",
          options: %{sourceUri: "rtsp://placeholder-19inrifjbsjb.it:12345/afwefae"}
        )

      assert response = %{"data" => %{"id" => id}} = json_response(conn, :created)
      assert_response_schema(response, "ComponentDetailsResponse", @schema)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => [
                 %{"id" => ^id, "type" => "rtsp"}
               ]
             } = json_response(conn, :ok)["data"]
    end

    test "renders errors when component requires options not present in request", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "rtsp")

      assert json_response(conn, :bad_request)["errors"] == "Invalid request body structure"
    end
  end

  describe "delete component" do
    setup [:create_hls_component]

    test "deletes chosen component", %{conn: conn, room_id: room_id, component_id: component_id} do
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert response(conn, :no_content)

      conn = get(conn, ~p"/room/#{room_id}")

      assert %{
               "id" => ^room_id,
               "components" => []
             } = json_response(conn, :ok)["data"]
    end

    test "deletes not existing component", %{conn: conn, room_id: room_id} do
      component_id = "test123"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")

      assert json_response(conn, :not_found)["errors"] ==
               "Component #{component_id} does not exist"
    end

    test "deletes component from not exisiting room", %{conn: conn, component_id: component_id} do
      room_id = "abc"
      conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")
      assert json_response(conn, :not_found)["errors"] == "Room #{room_id} does not exist"
    end
  end

  defp create_hls_component(state) do
    conn = post(state.conn, ~p"/room/#{state.room_id}/component", type: "hls")

    assert %{"id" => id} = json_response(conn, :created)["data"]

    %{component_id: id}
  end
end
