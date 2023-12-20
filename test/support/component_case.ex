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

    assert %{"id" => id} =
             model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

    on_exit(fn ->
      conn = delete(conn, ~p"/room/#{id}")
      assert response(conn, :no_content)
    end)

    {:ok, %{conn: conn, room_id: id}}
  end

  @spec model_response(Plug.Conn.t(), integer() | atom(), String.t()) :: any()
  def model_response(conn, status, model) do
    response = Phoenix.ConnTest.json_response(conn, status)

    assert_response_schema(response, model)

    response
  end

  @spec assert_component_created(
          Plug.Conn.t(),
          Jellyfish.Room.id(),
          Jellyfish.Component.id(),
          String.t()
        ) :: map()
  def assert_component_created(conn, room_id, component_id, component_type) do
    conn = get(conn, ~p"/room/#{room_id}")

    assert %{
             "id" => ^room_id,
             "components" => [
               %{"id" => ^component_id, "type" => ^component_type}
             ]
           } = model_response(conn, :ok, "RoomDetailsResponse")["data"]

    conn
  end

  defp assert_response_schema(response, model) do
    OpenApiSpex.TestAssertions.assert_response_schema(response, model, @schema)
  end
end
