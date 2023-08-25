Mix.install([
  # Keep in mind that you should lock onto a specific version of Jellyfish
  # and the Jellyfish Server SDK in production code
  {:jellyfish_server_sdk, github: "jellyfish-dev/elixir_server_sdk", branch: "extend_create_room"}
])

defmodule Example do
  require Logger

  @jellyfish_hostname "localhost"
  @jellyfish_port 5002
  @jellyfish_token "development"

  def run(stream_uri) do
    client =
      Jellyfish.Client.new(
        server_address: "#{@jellyfish_hostname}:#{@jellyfish_port}",
        server_api_token: @jellyfish_token
      )

    with {:ok, %Jellyfish.Room{id: room_id}, _jellyfish_address} <-
           Jellyfish.Room.create(client, video_codec: :h264),
         {:ok, %Jellyfish.Component{id: _hls_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, Jellyfish.Component.HLS),
         {:ok, %Jellyfish.Component{id: _rtsp_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, %Jellyfish.Component.RTSP{
             source_uri: stream_uri
           }) do
      Logger.info("Components added successfully")
    else
      {:error, reason} ->
        Logger.error("""
        Error when attempting to communicate with Jellyfish: #{inspect(reason)}
        Make sure you have started it by running `mix phx.server`
        """)
    end
  end
end

case System.argv() do
  [stream_uri | _rest] -> Example.run(stream_uri)
  _empty -> raise("No stream URI specified, make sure you pass it as the argument to this script")
end
