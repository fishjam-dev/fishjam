defmodule JellyfishWeb.PeerSocketTest do
  use JellyfishWeb.ConnCase

  import ExUnit.CaptureLog

  alias Jellyfish.RoomService
  alias JellyfishWeb.PeerSocket

  @data "mediaEventData"

  setup %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]
    {:ok, _room_pid} = RoomService.find_room(room_id)

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => token} = json_response(conn, :created)["data"]

    on_exit(fn ->
      RoomService.delete_room(room_id)
    end)

    {:ok,
     %{
       room_id: room_id,
       authenticated?: false,
       token: token
     }}
  end

  describe "receiving messages from client" do
    setup [:authenticate]

    test "when message is valid Media Event", %{room_id: room_id, peer_id: peer_id} = state do
      room_pid = RoomService.find_room!(room_id)
      :erlang.trace(room_pid, true, [:receive])

      json = Jason.encode!(%{"type" => "mediaEvent", "data" => @data})
      send_from_client(json, state)

      # check if room process received the media event
      assert_receive {:trace, ^room_pid, :receive, {:media_event, ^peer_id, _data}}
    end

    test "authRequest when already connected", state do
      auth_msg =
        Jason.encode!(%{
          "type" => "controlMessage",
          "data" => %{"type" => "authRequest", "token" => state.token}
        })

      assert capture_log(fn -> send_from_client(auth_msg, state) end) =~
               ~r/peer already connected/
    end

    test "when message is not a json", state do
      assert capture_log(fn -> send_from_client("notajson", state) end) =~
               "Failed to decode message"
    end

    test "when message type is unexpected", state do
      json = Jason.encode!(%{"type" => 34})

      assert capture_log(fn -> send_from_client(json, state) end) =~
               "Received message with unexpected type"
    end

    test "when message has invalid structure", state do
      json = Jason.encode!(%{"notatype" => 45})

      assert capture_log(fn -> send_from_client(json, state) end) =~
               "Received message with invalid structure"
    end
  end

  describe "receiving messages from server" do
    test "when it is a valid Media Event" do
      assert {:push, {:text, json}, _state} = send_from_server({:media_event, @data})

      assert %{"type" => "mediaEvent", "data" => @data} === Jason.decode!(json)
    end

    test "when it is stop connection message" do
      assert {:stop, _reason, _state} = send_from_server({:stop_connection, :reason})
    end

    test "when room crashed", state do
      %{room_pid: room_pid} = authenticate(state)

      Process.exit(room_pid, :error)

      assert_receive(:room_crashed)
    end
  end

  def connect(params, connect_info \\ %{}) do
    map = %{
      endpoint: Endpoint,
      transport: :channel_test,
      options: [serializer: [{NoopSerializer, "~> 1.0.0"}]],
      params: params,
      connect_info: connect_info
    }

    with {:ok, state} <- PeerSocket.connect(map),
         {:ok, state} <- PeerSocket.init(state) do
      {:ok, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def send_from_client(message, state) do
    PeerSocket.handle_in({message, [opcode: :text]}, state)
  end

  def send_from_server(message), do: PeerSocket.handle_info(message, %{})

  def connect_setup(%{}) do
    {:ok, state} = connect(%{})
    state
  end

  def authenticate(state) do
    auth_message =
      %{
        "type" => "controlMessage",
        "data" => %{
          "type" => "authRequest",
          "token" => state.token
        }
      }
      |> Jason.encode!()

    {:reply, :ok, {:text, _message}, new_state} =
      PeerSocket.handle_in({auth_message, [opcode: :text]}, state)

    Map.merge(state, new_state)
  end
end
