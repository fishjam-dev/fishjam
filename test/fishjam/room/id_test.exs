defmodule Fishjam.Room.IDTest do
  use ExUnit.Case

  alias Fishjam.Room.ID, as: Subject

  describe "determine_node/1" do
    test "resolves node name from the provided room_id" do
      node_name = Node.self()
      room_id = Subject.generate()

      assert {:ok, node_name} == Subject.determine_node(room_id)
    end

    test "returns error if node is not detected in cluster" do
      invalid_room_id = Base.encode16("room_id-invalid_node", case: :lower)
      assert {:error, :invalid_node} == Subject.determine_node(invalid_room_id)
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
      Application.delete_env(:fishjam, :feature_flags)
    end

    test "executes generate/0 when feature flag is enabled and generates random id" do
      Application.put_env(:fishjam, :feature_flags, custom_room_name_disabled: true)
      refute {:ok, "custom_room_name"} == Subject.generate("custom_room_name")
    end

    test "parses custom room name when feature flag is disabled" do
      assert {:ok, "custom_room_name"} == Subject.generate("custom_room_name")
    end

    test "returns error when custom room doesn't meet naming criteria" do
      assert {:error, :invalid_room_id} = Subject.generate("invalid_characters//??$@!")
    end
  end
end
