defmodule Jellyfish.Event do
  @moduledoc false

  alias Jellyfish.Room

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    ComponentCrashed,
    HlsPlayable,
    MetricsReport,
    PeerConnected,
    PeerCrashed,
    PeerDisconnected,
    RoomCrashed,
    RoomCreated,
    RoomDeleted
  }

  @pubsub Jellyfish.PubSub
  @valid_topics [:server_notification, :metrics]

  def broadcast_metrics(message) do
    topic = :metrics
    Phoenix.PubSub.broadcast(@pubsub, Atom.to_string(topic), {topic, message})
  end

  def broadcast_server_notification({type, _content} = message, webhook_url)
      when type in [:room_deleted, :room_crashed] do
    topic = :server_notification
    Phoenix.PubSub.broadcast(@pubsub, Atom.to_string(topic), {topic, message})

    content = to_proto({topic, message})

    notification = %ServerMessage{content: content} |> ServerMessage.encode()

    Room.send_webhook_notification(notification, webhook_url)
  end

  def broadcast_server_notification(message, room_id) do
    topic = :server_notification
    Phoenix.PubSub.broadcast(@pubsub, Atom.to_string(topic), {topic, message})

    content = to_proto({topic, message})

    notification = %ServerMessage{content: content} |> ServerMessage.encode()

    Room.receive_room_notification(room_id, notification)
  end

  def subscribe(topic) when topic in @valid_topics do
    Phoenix.PubSub.subscribe(@pubsub, Atom.to_string(topic))
  end

  def to_proto({:server_notification, notification}) do
    to_proto_server_notification(notification)
  end

  def to_proto({:metrics, report}) do
    {:metrics_report, %MetricsReport{metrics: report}}
  end

  defp to_proto_server_notification({:room_created, room_id}),
    do: {:room_created, %RoomCreated{room_id: room_id}}

  defp to_proto_server_notification({:room_deleted, room_id}),
    do: {:room_deleted, %RoomDeleted{room_id: room_id}}

  defp to_proto_server_notification({:room_crashed, room_id}),
    do: {:room_crashed, %RoomCrashed{room_id: room_id}}

  defp to_proto_server_notification({:peer_connected, room_id, peer_id}),
    do: {:peer_connected, %PeerConnected{room_id: room_id, peer_id: peer_id}}

  defp to_proto_server_notification({:peer_disconnected, room_id, peer_id}),
    do: {:peer_disconnected, %PeerDisconnected{room_id: room_id, peer_id: peer_id}}

  defp to_proto_server_notification({:peer_crashed, room_id, peer_id}),
    do: {:peer_crashed, %PeerCrashed{room_id: room_id, peer_id: peer_id}}

  defp to_proto_server_notification({:component_crashed, room_id, component_id}),
    do: {:component_crashed, %ComponentCrashed{room_id: room_id, component_id: component_id}}

  defp to_proto_server_notification({:hls_playable, room_id, component_id}),
    do: {:hls_playable, %HlsPlayable{room_id: room_id, component_id: component_id}}
end
