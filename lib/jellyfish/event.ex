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
    PeerMetadataUpdated,
    RoomCrashed,
    RoomCreated,
    RoomDeleted,
    Track,
    TrackAdded,
    TrackMetadataUpdated,
    TrackRemoved
  }

  alias Membrane.RTC.Engine.Message

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

  defp to_proto_server_notification({:peer_metadata_updated, room_id, peer_id, metadata}),
    do:
      {:peer_metadata_updated,
       %PeerMetadataUpdated{room_id: room_id, peer_id: peer_id, metadata: Jason.encode!(metadata)}}

  defp to_proto_server_notification({:track_added, room_id, endpoint_info, track_info}) do
    {:track_added,
     %TrackAdded{
       room_id: room_id,
       endpoint_info: endpoint_info,
       track: to_proto_track(track_info)
     }}
  end

  defp to_proto_server_notification({:track_removed, room_id, endpoint_info, track_info}) do
    {:track_removed,
     %TrackRemoved{
       room_id: room_id,
       endpoint_info: endpoint_info,
       track: to_proto_track(track_info)
     }}
  end

  defp to_proto_server_notification({:track_metadata_updated, room_id, endpoint_info, track_id}) do
    {:track_metadata_updated,
     %TrackMetadataUpdated{
       room_id: room_id,
       endpoint_info: endpoint_info,
       track: to_proto_track(track_id)
     }}
  end

  defp to_proto_server_notification({:hls_playable, room_id, component_id}),
    do: {:hls_playable, %HlsPlayable{room_id: room_id, component_id: component_id}}

  defp to_proto_server_notification({:hls_uploaded, room_id}),
    do: {:hls_uploaded, %HlsUploaded{room_id: room_id}}

  defp to_proto_server_notification({:hls_upload_crashed, room_id}),
    do: {:hls_upload_crashed, %HlsUploadCrashed{room_id: room_id}}

  defp to_proto_track(%Jellyfish.Track{} = track) do
    %Track{
      id: track.id,
      type: to_proto_track_type(track.type),
      encoding: to_proto_encoding(track.encoding),
      metadata: Jason.encode!(track.metadata)
    }
  end

  defp to_proto_track(%Message.TrackAdded{} = track) do
    %Track{
      id: track.track_id,
      type: to_proto_track_type(track.track_type),
      encoding: to_proto_encoding(track.track_encoding),
      metadata: Jason.encode!(track.track_metadata)
    }
  end

  defp to_proto_encoding(:H264), do: :ENCODING_H264
  defp to_proto_encoding(:VP8), do: :ENCODING_VP8
  defp to_proto_encoding(:OPUS), do: :ENCODING_OPUS
  defp to_proto_encoding(_encoding), do: :ENCODING_UNSPECIFIED

  defp to_proto_track_type(:video), do: :TRACK_TYPE_VIDEO
  defp to_proto_track_type(:audio), do: :TRACK_TYPE_AUDIO
  defp to_proto_track_type(_type), do: :TRACK_TYPE_UNSPECIFIED
end
