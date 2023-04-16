defmodule JellyfishWeb.ServerSocketTest do
  use ExUnit.Case, async: true

  alias __MODULE__.Endpoint
  alias JellyfishWeb.{ServerSocket, WS}

  @port 5907
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"

  Application.put_env(
    :jellyfish,
    Endpoint,
    https: false,
    http: [port: @port],
    server: true
  )

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :jellyfish

    alias JellyfishWeb.ServerSocket

    socket "/socket/server", ServerSocket,
      websocket: true,
      longpoll: false
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

  test "invalid token" do
    {:ok, ws} = WS.start_link(@path)
    token = "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(token)

    :ok = WS.send_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "missing token" do
    {:ok, ws} = WS.start_link(@path)

    {_token, auth_request} =
      Application.fetch_env!(:jellyfish, :server_api_token)
      |> auth_request()
      |> pop_in([:data, :token])

    :ok = WS.send_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid auth request"}}, 1000
  end

  test "correct token" do
    {:ok, ws} = WS.start_link(@path)
    token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(token)

    :ok = WS.send_frame(ws, auth_request)
    assert_receive msg, 1000
    assert msg == auth_response()
  end

  test "closes on receiving a message from a client" do
    {:ok, ws} = WS.start_link(@path)
    token = Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(token)

    :ok = WS.send_frame(ws, auth_request)

    :ok = WS.send_frame(ws, %{type: "controlMessage", data: "dummy data"})

    assert_receive {:disconnected, {:remote, 1003, "operation not allowed"}}, 1000
  end

  defp auth_request(token) do
    %{
      type: "controlMessage",
      data: %{
        type: "authRequest",
        token: token
      }
    }
  end

  defp auth_response() do
    %{
      "type" => "controlMessage",
      "data" => %{
        "type" => "authenticated"
      }
    }
  end
end
