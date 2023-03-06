defmodule JellyfishWeb.SocketTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Jellyfish.Peer.WebRTC
  alias Jellyfish.{Room, RoomService}

  alias JellyfishWeb.{Endpoint, Socket}

  @data "mediaEventData"

  setup do
    {:ok, room} = RoomService.create_room(10)
    {:ok, room_pid} = RoomService.find_room(room.id)
    {:ok, peer} = Room.add_peer(room_pid, WebRTC)

    on_exit(fn ->
      RoomService.delete_room(room.id)
    end)

    %{room_id: room.id, peer_id: peer.id, room_pid: room_pid}
  end

  describe "connecting" do
    test "when credentials are valid", %{room_id: room_id, peer_id: peer_id, room_pid: room_pid} do
      assert {:ok, state} = connect(%{"room_id" => room_id, "peer_id" => peer_id})
      assert state.peer_id == peer_id
      assert state.room_id == room_id

      status =
        room_pid
        |> Room.get_state()
        |> Map.get(:peers)
        |> Map.get(peer_id)
        |> Map.get(:status)

      assert status == :connected
    end

    test "when peer is already connected", %{room_id: room_id, peer_id: peer_id} do
      assert {:ok, _state} = connect(%{"room_id" => room_id, "peer_id" => peer_id})
      assert {:error, :already_connected} = connect(%{"room_id" => room_id, "peer_id" => peer_id})
    end

    test "when room does not exist" do
      assert {:error, :room_not_found} =
               connect(%{"room_id" => "fake_room_id", "peer_id" => "fake_peer_id"})
    end

    test "when peer does not exist", %{room_id: room_id} do
      assert {:error, :peer_not_found} =
               connect(%{"room_id" => room_id, "peer_id" => "fake_peer_id"})
    end

    test "when request params are missing" do
      assert {:error, :no_params} = connect(%{"room_id" => "room_id", "not_peer_id" => "abc"})
    end
  end

  describe "receiving messages from client" do
    test "when message is valid Media Event", %{
      room_id: room_id,
      peer_id: peer_id,
      room_pid: room_pid
    } do
      :erlang.trace(room_pid, true, [:receive])

      json = Jason.encode!(%{"type" => "mediaEvent", "data" => @data})
      send_from_client(json, room_id, peer_id)

      # check if room process received the media event
      assert_receive {:trace, ^room_pid, :receive, {:media_event, ^peer_id, _data}}
    end

    test "when room does not exist" do
      json = Jason.encode!(%{"type" => "mediaEvent", "data" => @data})

      assert capture_log(fn -> send_from_client(json, "fake_room_id", "fake_peer_id") end) =~
               "Trying to send Media Event to room"
    end

    test "when message is not a json", %{room_id: room_id, peer_id: peer_id} do
      assert capture_log(fn -> send_from_client("notajson", room_id, peer_id) end) =~
               "Failed to decode message"
    end

    test "when message type is unexpected", %{room_id: room_id, peer_id: peer_id} do
      json = Jason.encode!(%{"type" => 34})

      assert capture_log(fn -> send_from_client(json, room_id, peer_id) end) =~
               "Received message with unexpected type"
    end

    test "when message has invalid structure", %{room_id: room_id, peer_id: peer_id} do
      json = Jason.encode!(%{"notatype" => 45})

      assert capture_log(fn -> send_from_client(json, room_id, peer_id) end) =~
               "Received message with invalid structure"
    end
  end

  describe "receiving messages from server" do
    test "when it is a valid Media Event" do
      assert {:push, {:text, json}, _state} = Socket.handle_info({:media_event, @data}, %{})

      assert %{"type" => "mediaEvent", "data" => @data} === Jason.decode!(json)
    end

    test "when it is stop connection message" do
      assert {:stop, _reason, _state} = Socket.handle_info({:stop_connection, :reason}, %{})
    end
  end

  defp connect(params, connect_info \\ %{}) do
    map = %{
      endpoint: Endpoint,
      transport: :channel_test,
      options: [serializer: [{NoopSerializer, "~> 1.0.0"}]],
      params: params,
      connect_info: connect_info
    }

    with {:ok, state} <- Socket.connect(map),
         {:ok, state} <- Socket.init(state) do
      {:ok, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_from_client(message, room_id, peer_id) do
    Socket.handle_in({message, [opcode: :text]}, %{room_id: room_id, peer_id: peer_id})
  end
end
