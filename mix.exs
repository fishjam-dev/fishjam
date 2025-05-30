defmodule Fishjam.MixProject do
  use Mix.Project

  def project do
    [
      app: :fishjam,
      version: "0.6.3",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      # TODO: Remove once core fix bug
      consolidate_protocols: false,

      # hex
      description: "Fishjam media server",

      # test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Fishjam.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(env) when env in [:test, :test_cluster], do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.1"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:elixir_uuid, "~> 1.2"},
      {:cors_plug, "~> 3.0"},
      {:open_api_spex, "~> 3.19"},
      {:ymlr, "~> 3.0"},
      {:bunch, "~> 1.6"},
      {:logger_json, "~> 5.1"},

      # aws deps
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.6"},

      # protobuf deps
      {:protobuf, "~> 0.12.0"},

      # Membrane deps
      {:membrane_core, "~> 1.1.0-rc1", override: true},
      {:membrane_rtc_engine,
       github: "fishjam-dev/membrane_rtc_engine",
       sparse: "engine",
       ref: "dc3ffd0051dd3aec6de142076ac01a5f79fe846a",
       override: "true"},
      {:membrane_rtc_engine_webrtc,
       github: "fishjam-dev/membrane_rtc_engine",
       sparse: "webrtc",
       ref: "dc3ffd0051dd3aec6de142076ac01a5f79fe846a",
       override: "true"},
      {:membrane_rtc_engine_hls, "~> 0.7.0"},
      {:membrane_rtc_engine_recording,
       github: "fishjam-dev/membrane_rtc_engine",
       sparse: "recording",
       ref: "dc3ffd0051dd3aec6de142076ac01a5f79fe846a",
       override: "true"},
      {:membrane_rtc_engine_rtsp,
       github: "fishjam-dev/membrane_rtc_engine",
       sparse: "rtsp",
       ref: "dc3ffd0051dd3aec6de142076ac01a5f79fe846a",
       override: "true"},
      {:membrane_rtc_engine_file, "~> 0.5.0"},
      {:membrane_rtc_engine_sip,
       github: "fishjam-dev/membrane_rtc_engine",
       sparse: "sip",
       ref: "dc3ffd0051dd3aec6de142076ac01a5f79fe846a",
       override: "true"},
      {:membrane_telemetry_metrics, "~> 0.1.0"},

      # HLS endpoints deps
      {:membrane_audio_mix_plugin, "~> 0.16.0"},
      {:membrane_video_compositor_plugin, "~> 0.7.0"},

      # Dialyzer and credo
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},

      # Load balancing
      {:libcluster, "~> 3.3"},
      {:httpoison, "~> 2.0"},

      # Mocking timer in tests
      {:klotho, "~> 0.1.0"},

      # Test deps
      {:websockex, "~> 0.4.3", only: [:test, :test_cluster], runtime: false},
      {:excoveralls, "~> 0.15.0", only: :test, runtime: false},
      {:mox, "~> 1.0", only: [:test, :test_cluster]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "api.spec": &generate_api_spec/1,
      test: ["test --exclude cluster"],
      "test.cluster.epmd": [
        "cmd docker compose -f docker-compose-epmd.yaml up test; docker compose -f docker-compose-epmd.yaml down"
      ],
      "test.cluster.dns": [
        "cmd docker compose -f docker-compose-dns.yaml up test; docker compose -f docker-compose-dns.yaml down"
      ]
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp generate_api_spec(_args) do
    output_filename = "openapi.yaml"
    generated_filename = "openapi-gen.yaml"

    Mix.shell().info("Generating #{output_filename}...")

    {_io_stream, exit_status} =
      System.cmd(
        "mix",
        [
          "openapi.spec.yaml",
          "--start-app=false",
          "--spec",
          "FishjamWeb.ApiSpec",
          generated_filename
        ],
        into: IO.stream()
      )

    if exit_status != 0, do: raise("Failed to generate OpenAPI spec")

    File.write!(output_filename, """
    # This file has been generated using OpenApiSpex. Do not edit manually!
    # Run `mix api.spec` to regenerate

    """)

    File.read!(generated_filename)
    |> then(&File.write!(output_filename, &1, [:append]))

    File.rm!(generated_filename)

    Mix.shell().info("Successfully generated #{output_filename}")
  end
end
