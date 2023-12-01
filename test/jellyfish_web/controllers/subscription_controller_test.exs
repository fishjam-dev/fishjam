defmodule JellyfishWeb.SubscriptionControllerTest do
  use JellyfishWeb.ConnCase

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

  describe "subscription" do
    test "returns error when room doesn't exist", %{conn: conn} do
      conn = post(conn, ~p"/hls/invalid_room_id/subscribe/", tracks: ["track-1", "track-2"])
      assert json_response(conn, :not_found)["errors"] == "Room invalid_room_id does not exist"
    end

    test "returns error when hls component doesn't exist", %{conn: conn, room_id: room_id} do
      conn = post(conn, ~p"/hls/#{room_id}/subscribe/", tracks: ["track-1", "track-2"])
      assert json_response(conn, :bad_request)["errors"] == "HLS component does not exist"
    end

    test "returns error when subscribe mode is :auto", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "hls",
          options: %{subscribeMode: "auto"}
        )

      assert %{
               "data" => %{
                 "type" => "hls",
                 "properties" => %{"subscribeMode" => "auto"}
               }
             } =
               json_response(conn, :created)

      conn = post(conn, ~p"/hls/#{room_id}/subscribe/", tracks: ["track-1", "track-2"])

      assert json_response(conn, :bad_request)["errors"] ==
               "HLS component option `subscribe_mode` is set to :auto"
    end

    test "return success when subscribe mode is :manual", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "hls",
          options: %{subscribeMode: "manual"}
        )

      assert %{
               "data" => %{
                 "type" => "hls",
                 "properties" => %{"subscribeMode" => "manual"}
               }
             } =
               json_response(conn, :created)

      conn = post(conn, ~p"/hls/#{room_id}/subscribe/", tracks: ["track-1", "track-2"])

      assert response(conn, :created) == "Successfully subscribed for tracks"
    end
  end
end
