defmodule Jellyfish.RoomTest do
  use ExUnit.Case, async: true

  alias Jellyfish.{Peer, Room}

  @purge_timeout_s 60
  @purge_timeout_ms @purge_timeout_s * 1000
  @message_timeout_ms 20

  setup do
    Klotho.Mock.reset()
    Klotho.Mock.freeze()
  end

  describe "peerless purge" do
    test "happens if peers never joined" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, _id} = Room.start(config)
      Process.monitor(pid)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)

      assert_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms
    end

    test "happens if peers joined, then left" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, id} = Room.start(config)
      Process.monitor(pid)

      {:ok, peer} = Room.add_peer(id, Peer.WebRTC)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = Room.remove_peer(id, peer.id)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      assert_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms
    end

    test "does not happen if peers rejoined quickly" do
      {:ok, config} = Room.Config.from_params(%{"peerlessPurgeTimeout" => @purge_timeout_s})
      {:ok, pid, id} = Room.start(config)
      Process.monitor(pid)

      {:ok, peer} = Room.add_peer(id, Peer.WebRTC)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = Room.remove_peer(id, peer.id)

      Klotho.Mock.warp_by(@purge_timeout_ms |> div(2))
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      {:ok, _peer} = Room.add_peer(id, Peer.WebRTC)
      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = GenServer.stop(pid)
    end

    test "does not happen when not configured" do
      {:ok, config} = Room.Config.from_params(%{})
      {:ok, pid, _id} = Room.start(config)

      Klotho.Mock.warp_by(@purge_timeout_ms + 10)
      refute_receive {:DOWN, _ref, :process, ^pid, :normal}, @message_timeout_ms

      :ok = GenServer.stop(pid)
    end
  end
end
