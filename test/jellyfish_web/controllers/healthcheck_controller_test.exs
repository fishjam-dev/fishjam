defmodule JellyfishWeb.HealthcheckControllerTest do
  use JellyfishWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  @schema JellyfishWeb.ApiSpec.spec()

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    [conn: conn]
  end

  test "healthcheck without distribution", %{conn: conn} do
    conn = get(conn, ~p"/health")
    response = json_response(conn, :ok)
    assert_response_schema(response, "HealthcheckResponse", @schema)

    assert %{
             "status" => "UP",
             "uptime" => _uptime,
             "distribution" => %{
               "enabled" => false,
               "nodeStatus" => "DOWN",
               "nodesInCluster" => 0
             }
           } = response["data"]
  end
end
