defmodule FishjamWeb.ComponentCase do
  @moduledoc """
  This module defines the test case to be used by
  Fishjam Component tests.
  """

  use ExUnit.CaseTemplate
  use FishjamWeb.ConnCase

  alias Fishjam.RoomService

  using do
    quote do
      import FishjamWeb.ComponentCase
    end
  end

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:fishjam, :server_api_token)
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
          Fishjam.Room.id(),
          Fishjam.Component.id(),
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

  @spec map_keys_to_string(map()) :: map()
  def map_keys_to_string(map) do
    Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp assert_response_schema(response, model) do
    OpenApiSpex.TestAssertions.assert_response_schema(
      response,
      model,
      FishjamWeb.ApiSpec.spec()
    )
  end

  @spec create_h264_room(context :: term()) :: map()
  def create_h264_room(%{conn: conn}) do
    conn = post(conn, ~p"/room", videoCodec: "h264")

    assert %{"id" => room_id} =
             model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

    on_exit(fn ->
      RoomService.delete_room(room_id)
    end)

    %{room_id: room_id}
  end
end
