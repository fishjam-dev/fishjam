defmodule JellyfishWeb.ApiSpec.Component.HLS do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Metadata do
    @moduledoc false

    require OpenApiSpex
    alias OpenApiSpex.Schema

    OpenApiSpex.schema(%{
      title: "ComponentMetadataHLS",
      description: "Metadata specific to the HLS component",
      type: :object,
      properties: %{
        playable: %Schema{
          type: :boolean,
          description: "Whether the generated HLS playlist is playable"
        },
        lowLatency: %Schema{
          type: :boolean,
          description: "Whether the component uses LL-HLS"
        },
        targetWindowDuration: %Schema{
          type: :integer,
          description: "Duration of stream available for viewer",
          nullable: true
        },
        persistent: %Schema{
          type: :boolean,
          description: "Whether the video is stored after end of stream"
        },
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the HLS component should subscribe to tracks automatically or manually",
          enum: ["auto", "manual"]
        }
      },
      required: [:playable, :lowLatency, :persistent, :targetWindowDuration, :subscribeMode]
    })
  end

  defmodule S3 do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "S3Credentials",
      description:
        "An AWS S3 credential that will be used to send HLS stream. The stream will only be uploaded if credentials are provided",
      type: :object,
      properties: %{
        accessKeyId: %Schema{
          type: :string,
          description: "An AWS access key identifier, linked to your AWS account."
        },
        secretAccessKey: %Schema{
          type: :string,
          description: "The secret key that is linked to the Access Key ID."
        },
        region: %Schema{
          type: :string,
          description: "The AWS region where your bucket is located."
        },
        bucket: %Schema{
          type: :string,
          description: "The name of the S3 bucket where your data will be stored."
        }
      },
      required: [:accessKeyId, :secretAccessKey, :region, :bucket]
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ComponentOptionsHLS",
      description: "Options specific to the HLS component",
      type: :object,
      properties: %{
        lowLatency: %Schema{
          type: :boolean,
          description: "Whether the component should use LL-HLS",
          default: false
        },
        targetWindowDuration: %Schema{
          type: :integer,
          description: "Duration of stream available for viewer",
          nullable: true
        },
        persistent: %Schema{
          type: :boolean,
          description: "Whether the video is stored after end of stream",
          default: false
        },
        s3: %Schema{
          type: :object,
          description: "Credentials to AWS S3 bucket.",
          oneOf: [S3],
          nullable: true
        },
        subscribeMode: %Schema{
          type: :string,
          description:
            "Whether the HLS component should subscribe to tracks automatically or manually.",
          enum: ["auto", "manual"],
          default: "auto"
        }
      },
      required: []
    })
  end

  OpenApiSpex.schema(%{
    title: "ComponentHLS",
    description: "Describes HLS component",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned component ID", example: "component-1"},
      # FIXME: due to cyclic imports, we can't use ApiSpec.Component.Type here
      type: %Schema{type: :string, description: "Component type", example: "hls"},
      metadata: Metadata
    },
    required: [:id, :type, :metadata]
  })
end
