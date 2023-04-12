Mix.install([
  {:jellyfish_server_sdk, "~> 0.1.0"}
])

defmodule Example do
  require Logger

  @jellyfish_hostname "localhost"
  @jellyfish_port 4000
  @stream_uri "PUT_STREAM_URI_HERE"

  def run() do
    client = Jellyfish.Client.new("http://#{@jellyfish_hostname}:#{@jellyfish_port}")

    with {:ok, %Jellyfish.Room{id: room_id}} <- Jellyfish.Room.create(client),
         {:ok, %Jellyfish.Component{id: _hls_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, "hls"),
         {:ok, %Jellyfish.Component{id: _rtsp_component_id}} <-
           Jellyfish.Room.add_component(client, room_id, "rtsp", source_uri: @stream_uri) do
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

Example.run()
