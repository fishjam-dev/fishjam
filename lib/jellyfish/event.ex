defmodule Jellyfish.Event do
  @moduledoc false

  alias Jellyfish.ServerMessage.{
    ComponentCrashed,
    HlsPlayable,
    HlsUploadCrashed,
    HlsUploaded,
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

  def broadcast_metrics(message), do: broadcast(:metrics, message)

  def broadcast_server_notification(message), do: broadcast(:server_notification, message)

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, Atom.to_string(topic), {topic, message})
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

  defp to_proto_server_notification({:hls_uploaded, room_id}),
    do: {:hls_uploaded, %HlsUploaded{room_id: room_id}}

  defp to_proto_server_notification({:hls_upload_crashed, room_id}),
    do: {:hls_upload_crashed, %HlsUploadCrashed{room_id: room_id}}
end
