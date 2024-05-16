Mix.install([
  # Keep in mind that you should lock onto a specific version of Fishjam
  # and the Fishjam Server SDK in production code
  {:fishjam_server_sdk, github: "fishjam-dev/elixir_server_sdk"}
])

defmodule Example do
  require Logger

  @fishjam_hostname "localhost"
  @fishjam_port 5002
  @fishjam_token "development"

  def run(stream_uri) do
    client =
      Fishjam.Client.new(
        server_address: "#{@fishjam_hostname}:#{@fishjam_port}",
        server_api_token: @fishjam_token
      )

    with {:ok, %Fishjam.Room{id: room_id}, _fishjam_address} <-
           Fishjam.Room.create(client, video_codec: :h264),
         {:ok, %Fishjam.Component{id: _hls_component_id}} <-
           Fishjam.Room.add_component(client, room_id, Fishjam.Component.HLS),
         {:ok, %Fishjam.Component{id: _rtsp_component_id}} <-
           Fishjam.Room.add_component(client, room_id, %Fishjam.Component.RTSP{
             source_uri: stream_uri
           }) do
      Logger.info("Components added successfully")
    else
      {:error, reason} ->
        Logger.error("""
        Error when attempting to communicate with Fishjam: #{inspect(reason)}
        Make sure you have started it by running `mix phx.server`
        """)
    end
  end
end

case System.argv() do
  [stream_uri | _rest] -> Example.run(stream_uri)
  _empty -> raise("No stream URI specified, make sure you pass it as the argument to this script")
end
