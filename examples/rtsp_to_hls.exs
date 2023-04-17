Mix.install([
  {:jellyfish_server_sdk, "~> 0.1.1"}
])

defmodule Example do
  require Logger

  @jellyfish_hostname "localhost"
  @jellyfish_port 4000
  @jellyfish_token "development"

  def run(stream_uri) do
    client =
      Jellyfish.Client.new("http://#{@jellyfish_hostname}:#{@jellyfish_port}", @jellyfish_token)

    with {:ok, %Jellyfish.Room{id: room_id}} <- Jellyfish.Room.create(client),
         {:ok, %Jellyfish.Component{id: _hls_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, "hls"),
         {:ok, %Jellyfish.Component{id: _rtsp_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, "rtsp", sourceUri: stream_uri) do
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
