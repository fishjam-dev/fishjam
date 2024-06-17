defmodule FishjamWeb.HealthcheckControllerTest do
  use FishjamWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  @schema FishjamWeb.ApiSpec.spec()

  @commit_hash_length 7

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:fishjam, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    [conn: conn]
  end

  test "healthcheck without distribution", %{conn: conn} do
    conn = get(conn, ~p"/health")
    response = json_response(conn, :ok)
    assert_response_schema(response, "HealthcheckResponse", @schema)

    version = Fishjam.version()

    assert %{
             "localStatus" => %{
              "status" => "UP",
              "nodeName" => _,
              "uptime" => _,
              "version" => ^version,
              "gitCommit" => commit
             },
             "distributionEnabled" => false,
             "nodesInCluster" => 1,
             "nodesStatus" => _
           } = response["data"]

    assert commit == "dev" || String.length(commit) == @commit_hash_length
  end
end
