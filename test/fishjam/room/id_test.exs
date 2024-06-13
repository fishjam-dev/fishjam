defmodule Fishjam.Room.IDTest do
  use ExUnit.Case

  alias Fishjam.Room.ID, as: Subject

  setup_all do
    current = Application.fetch_env!(:fishjam, :feature_flags)

    on_exit(fn ->
      Application.put_env(:fishjam, :feature_flags, current)
    end)
  end

  describe "determine_node/1" do
    test "resolves node name from the provided room_id" do
      node_name = Node.self()
      room_id = Subject.generate()

      assert {:ok, node_name} == Subject.determine_node(room_id)
    end

    test "returns error if node is not detected in cluster" do
      old_values = Application.get_env(:fishjam, :feature_flags)
      Application.put_env(:fishjam, :feature_flags, custom_room_name_disabled: true)

      on_exit(fn ->
        Application.put_env(:fishjam, :feature_flags, old_values)
      end)

      invalid_node = :invalid_node |> Atom.to_string() |> Base.encode16(case: :lower)
      invalid_room_id = "room-id-#{invalid_node}"

      if Fishjam.FeatureFlags.request_routing_enabled?() do
        assert {:error, :node_not_found} == Subject.determine_node(invalid_room_id)
      end
    end

    test "returns ok self node if feature flag is disabled" do
      old_values = Application.get_env(:fishjam, :feature_flags)
      Application.put_env(:fishjam, :feature_flags, custom_room_name_disabled: false)

      on_exit(fn ->
        Application.put_env(:fishjam, :feature_flags, old_values)
      end)

      invalid_node = :invalid_node |> Atom.to_string() |> Base.encode16(case: :lower)
      invalid_room_id = "room-id-#{invalid_node}"
      assert {:ok, :nonode@nohost} == Subject.determine_node(invalid_room_id)
    end
  end

  describe "generate/0" do
    test "room_id last part is based on the node name" do
      room1_id = Subject.generate()
      room2_id = Subject.generate()

      node_part_from_room1 = room1_id |> String.split("-") |> Enum.take(-1)
      node_part_from_room2 = room2_id |> String.split("-") |> Enum.take(-1)

      assert node_part_from_room1 == node_part_from_room2
    end

    test "generated room_id has 5 parts" do
      room_id = Subject.generate()
      assert room_id |> String.split("-") |> length() == 5
    end
  end

  describe "generate/1" do
    setup do
      old_values = Application.get_env(:fishjam, :feature_flags)
      Application.delete_env(:fishjam, :feature_flags)

      on_exit(fn ->
        Application.put_env(:fishjam, :feature_flags, old_values)
      end)
    end

    test "executes generate/0 when feature flag is enabled and generates random id" do
      Application.put_env(:fishjam, :feature_flags, request_routing_enabled?: true)
      refute {:ok, "custom_room_name"} == Subject.generate("custom_room_name")
    end

    test "parses custom room name when feature flag is disabled" do
      Application.put_env(:fishjam, :feature_flags, request_routing_enabled?: false)
      assert {:ok, "custom_room_name"} == Subject.generate("custom_room_name")
    end

    test "returns error when custom room doesn't meet naming criteria" do
      Application.put_env(:fishjam, :feature_flags, request_routing_enabled?: false)
      assert {:error, :invalid_room_id} = Subject.generate("invalid_characters//??$@!")
    end
  end
end
