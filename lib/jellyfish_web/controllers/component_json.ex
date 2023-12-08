defmodule JellyfishWeb.ComponentJSON do
  @moduledoc false

  alias Jellyfish.Component.{File, HLS, RTSP}
  alias Jellyfish.Utils.ParserJSON

  def show(%{component: component}) do
    %{data: data(component)}
  end

  def data(component) do
    type =
      case component.type do
        HLS -> "hls"
        RTSP -> "rtsp"
        File -> "file"
      end

    %{
      id: component.id,
      type: type,
      properties: component.properties |> ParserJSON.camel_case_keys()
    }
  end
end
