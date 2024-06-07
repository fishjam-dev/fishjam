defmodule FishjamWeb.ApiSpec.Component.HLS.S3 do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

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
    required: [:accessKeyId, :secretAccessKey, :region, :bucket],
    nullable: true
  })
end
