defmodule JellyfishWeb.ApiSpec.HLS do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Params do
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "HlsParams",
      description: "Hls request params",
      type: :object,
      properties: %{
        _HLS_msn: %Schema{
          type: :integer,
          minimum: 0,
          example: 10,
          description: "Segment sequence number",
          nullable: true
        },
        _HLS_part: %Schema{
          type: :integer,
          minimum: 0,
          example: 10,
          description: "Partial segment sequence number",
          nullable: true
        },
        _HLS_skip: %Schema{
          type: :string,
          enum: ["YES"],
          example: "YES",
          description: "Is delta manifest requested",
          nullable: true
        }
      }
    })
  end

  defmodule Response do
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "HlsResponse",
      description: "Requested file",
      type: :string
    })
  end
end
