defmodule FishjamWeb.ComponentJSON do
  @moduledoc false

  alias Fishjam.Component.{File, HLS, Recording, RTSP, SIP}
  alias Fishjam.Utils.ParserJSON

  def show(%{component: component}) do
    %{data: data(component)}
  end

  def data(component) do
    type =
      case component.type do
        HLS -> "hls"
        RTSP -> "rtsp"
        File -> "file"
        SIP -> "sip"
        Recording -> "recording"
      end

    %{
      id: component.id,
      type: type,
      properties: component.properties |> ParserJSON.camel_case_keys(),
      tracks: component.tracks |> Map.values() |> Enum.map(&Map.from_struct/1)
    }
  end
end
