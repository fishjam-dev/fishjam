defmodule JellyfishWeb.HLSController do
  use JellyfishWeb, :controller

  alias Plug.Conn

  @spec index(Conn.t(), map) :: Conn.t()
  def index(
        conn,
        %{
          "room_id" => room_id,
          "filename" => filename,
        }
      ) do
    base_path = Application.fetch_env!(:jellyfish, :output_base_path)
    file_path = Path.join([base_path, "hls_output", room_id, filename])
    Conn.send_file(conn, 200, file_path)
  end
end
