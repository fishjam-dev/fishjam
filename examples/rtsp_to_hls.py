import sys

# You can install the Jellyfish Python Server SDK by running `pip install jellyfish-server-sdk`
from jellyfish import RoomApi, ComponentOptionsHLS, ComponentOptionsRTSP


JELLYFISH_HOSTNAME="localhost"
JELLYFISH_PORT=5002
JELLYFISH_TOKEN="development"


if len(sys.argv) > 1:
    stream_uri = sys.argv[1]
else:
    raise RuntimeError("No stream URI specified, make sure you pass it as the argument to this script")

try:
    room_api = RoomApi(server_address=f"{JELLYFISH_HOSTNAME}:{JELLYFISH_PORT}", server_api_token=JELLYFISH_TOKEN)

    _jellyfish_address, room = room_api.create_room(video_codec="h264")
    _component_hls = room_api.add_component(room.id, options=ComponentOptionsHLS())
    _component_rtsp = room_api.add_component(room.id, options=ComponentOptionsRTSP(source_uri=stream_uri))

    print("Components added successfully")

except Exception as e:
    print(f"""
    Error when attempting to communicate with Jellyfish: {e}
    Make sure you have started it by running `mix phx.server`
    """)
    sys.exit(1)
