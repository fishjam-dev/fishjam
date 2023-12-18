defmodule JellyfishWeb.ComponentCase do
  @moduledoc """
  This module defines the test case to be used by
  Jellyfish Component tests.
  """

  use ExUnit.CaseTemplate
  use JellyfishWeb.ConnCase

  @schema JellyfishWeb.ApiSpec.spec()

  using do
    quote do
      import JellyfishWeb.ComponentCase
    end
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)
    conn = put_req_header(conn, "accept", "application/json")

    conn = post(conn, ~p"/room")
    assert %{"id" => id} = json_response(conn, :created)["data"]["room"]

    on_exit(fn ->
      conn = delete(conn, ~p"/room/#{id}")
      assert response(conn, :no_content)
    end)

    {:ok, %{conn: conn, room_id: id}}
  end

  def assert_response_schema(response, title) do
    OpenApiSpex.TestAssertions.assert_response_schema(response, title, @schema)
  end
end
