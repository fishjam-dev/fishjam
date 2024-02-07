defmodule Jellyfish.RoomTest do
  use ExUnit.Case, async: true

  alias Jellyfish.{Peer, Room}

  @purge_timeout_s 1
  @message_timeout_ms @purge_timeout_s * 1000 + 10

  describe "peerless purge" do
    test "happens if peers never joined" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, _id} = Room.start(config)
      Process.monitor(pid)

      assert_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms
    end

    test "happens if peers joined, then left" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, id} = Room.start(config)
      Process.monitor(pid)

      {:ok, peer} = Room.add_peer(id, Peer.WebRTC)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = Room.remove_peer(id, peer.id)
      assert_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms
    end

    test "does not happen if peers rejoined quickly" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, id} = Room.start(config)
      Process.monitor(pid)

      {:ok, peer} = Room.add_peer(id, Peer.WebRTC)

      :ok = Room.remove_peer(id, peer.id)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms |> div(2)

      {:ok, _peer} = Room.add_peer(id, Peer.WebRTC)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = GenServer.stop(pid)
    end

    test "does not happen when not configured" do
      {:ok, config} = Room.Config.from_params(%{})
      {:ok, pid, _id} = Room.start(config)

      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = GenServer.stop(pid)
    end
  end
end
