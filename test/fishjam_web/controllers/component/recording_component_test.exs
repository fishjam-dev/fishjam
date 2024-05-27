defmodule FishjamWeb.Component.RecordingComponentTest do
  use FishjamWeb.ConnCase
  use FishjamWeb.ComponentCase

  import Mox

  alias Fishjam.RoomService

  @s3_credentials %{
    accessKeyId: "access_key_id",
    secretAccessKey: "secret_access_key",
    region: "region",
    bucket: "bucket"
  }

  @path_prefix "path_prefix"

  setup_all do
    Application.put_env(:fishjam, :components_used, [Fishjam.Component.Recording])

    mock_http_request()

    on_exit(fn ->
      Application.put_env(:fishjam, :components_used, [])
    end)
  end

  setup %{test: name} do
    IO.inspect("\n\nTEST_STARTED: #{name}")

    on_exit(fn ->
      IO.inspect("TEST_ENDED: #{name}\n\n")
    end)
  end

  describe "create recording component" do
    setup [:create_h264_room]
    setup :set_mox_from_context

    test "renders component with required options", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{credentials: Enum.into(@s3_credentials, %{}), pathPrefix: @path_prefix}
        )

      prefix = "#{@path_prefix}/#{room_id}/part_"

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert properties == %{"subscribeMode" => "auto"}

      path_prefix = get_recording_path_prefix(room_id, id)
      assert String.starts_with?(path_prefix, prefix)

      assert_component_created(conn, room_id, id, "recording")

      # Try to add another recording component
      conn = post(conn, ~p"/room/#{room_id}/component", type: "recording")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Reached recording components limit in room #{room_id}"

      assert_component_removed(conn, room_id, id)
    end

    setup :set_mox_from_context

    test "renders component when credentials are passed in config", %{
      conn: conn,
      room_id: room_id
    } do
      put_s3_envs(path_prefix: nil, credentials: @s3_credentials)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      prefix = "#{@path_prefix}/#{room_id}/part_"

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert properties == %{"subscribeMode" => "auto"}

      path_prefix = get_recording_path_prefix(room_id, id)
      assert String.starts_with?(path_prefix, prefix)

      assert_component_created(conn, room_id, id, "recording")
      assert_component_removed(conn, room_id, id)

      clean_s3_envs()
    end

    test "path prefix modify when recording is created second time",
         %{
           conn: conn,
           room_id: room_id
         } do
      put_s3_envs(path_prefix: nil, credentials: @s3_credentials)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      prefix = "#{@path_prefix}/#{room_id}/part_"

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert properties == %{"subscribeMode" => "auto"}

      path_prefix1 = get_recording_path_prefix(room_id, id)
      assert String.starts_with?(path_prefix1, prefix)

      assert_component_created(conn, room_id, id, "recording")
      assert_component_removed(conn, room_id, id)

      # Second recording
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert properties == %{"subscribeMode" => "auto"}

      assert_component_created(conn, room_id, id, "recording")

      path_prefix2 = get_recording_path_prefix(room_id, id)

      assert String.starts_with?(path_prefix2, prefix)

      assert path_prefix1 != path_prefix2
      assert_component_removed(conn, room_id, id)
      clean_s3_envs()
    end

    test "renders component when path prefix is passed in config", %{
      conn: conn,
      room_id: room_id
    } do
      put_s3_envs(path_prefix: @path_prefix, credentials: nil)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{credentials: Enum.into(@s3_credentials, %{})}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "recording",
                 "properties" => properties
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert properties == %{"subscribeMode" => "auto"}

      path_prefix = get_recording_path_prefix(room_id, id)

      assert String.starts_with?(path_prefix, @path_prefix)

      assert_component_created(conn, room_id, id, "recording")
      assert_component_removed(conn, room_id, id)
      clean_s3_envs()
    end

    test "renders error when credentials are passed both in config and request", %{
      conn: conn,
      room_id: room_id
    } do
      put_s3_envs(path_prefix: nil, credentials: @s3_credentials)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{credentials: @s3_credentials}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Conflicting S3 credentials supplied via environment variables and the REST API. Overrides on existing values are disallowed"

      clean_s3_envs()
    end

    test "renders error when path prefix is passed both in config and request", %{
      conn: conn,
      room_id: room_id
    } do
      put_s3_envs(path_prefix: @path_prefix, credentials: @s3_credentials)

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Conflicting S3 path prefix supplied via environment variables and the REST API. Overrides on existing values are disallowed"

      clean_s3_envs()
    end

    test "renders errors when required options are missing", %{conn: conn, room_id: room_id} do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "recording",
          options: %{pathPrefix: @path_prefix}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "S3 credentials has to be passed either by request or at application startup as envs"
    end

    test "renders errors when video codec is different than h264 - vp8", %{conn: conn} do
      put_s3_envs(path_prefix: nil, credentials: @s3_credentials)

      conn = post(conn, ~p"/room", videoCodec: "vp8")

      assert %{"id" => room_id} =
               model_response(conn, :created, "RoomCreateDetailsResponse")["data"]["room"]

      conn = post(conn, ~p"/room/#{room_id}/component", type: "recording")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Incompatible video codec enforced in room #{room_id}"

      RoomService.delete_room(room_id)
      clean_s3_envs()
    end
  end

  defp mock_http_request() do
    stub(ExAws.Request.HttpMock, :request, fn _method, _url, _req_body, _headers, _http_opts ->
      {:ok, %{status_code: 200, headers: %{}}}
    end)
  end

  defp put_s3_envs(path_prefix: path_prefix, credentials: credentials) do
    Application.put_env(:fishjam, :s3_config,
      path_prefix: path_prefix,
      credentials: credentials
    )
  end

  defp clean_s3_envs() do
    Application.put_env(:fishjam, :s3_config, path_prefix: nil, credentials: nil)
  end

  defp get_recording_path_prefix(room_id, component_id) do
    assert {:ok, room_state} = RoomService.get_room(room_id)

    {_store, %{path_prefix: path_prefix}} =
      room_state
      |> get_in([:components, component_id, :engine_endpoint])
      |> Map.fetch!(:stores)
      |> Enum.find(fn
        {_store, %{path_prefix: path_prefix}} -> path_prefix
        _other -> false
      end)

    path_prefix
  end

  defp assert_component_removed(conn, room_id, component_id) do
    conn = delete(conn, ~p"/room/#{room_id}/component/#{component_id}")
    assert response(conn, :no_content)

    conn
  end
end
