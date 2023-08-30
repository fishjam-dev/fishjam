defmodule Jellyfish.MixProject do
  use Mix.Project

  def project do
    [
      app: :jellyfish,
      version: "0.2.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Jellyfish media server",
      package: package(),

      # test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "test.cluster": :test,
        "test.cluster.ci": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Jellyfish.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(env) when env in [:test, :ci], do: ["lib", "test/support"]
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
      {:uuid, "~> 1.1"},
      {:cors_plug, "~> 3.0"},
      {:open_api_spex, "~> 3.16"},
      {:ymlr, "~> 3.0"},

      # protobuf deps
      {:protobuf, "~> 0.12.0"},

      # Membrane deps
      {:membrane_rtc_engine, "~> 0.17.0", override: true},
      {:membrane_rtc_engine_webrtc, "~> 0.2.1", override: true},
      {:membrane_rtc_engine_hls, github: "jellyfish-dev/membrane_rtc_engine", sparse: "hls", branch: "fix/segment_duration" , override: true},
      {:membrane_http_adaptive_stream_plugin, github: "membraneframework/membrane_http_adaptive_stream_plugin", branch: "feature/partial-serialization", override: true},
      {:membrane_rtc_engine_rtsp, "~> 0.2.0"},
      {:membrane_ice_plugin, "~> 0.16.0"},
      {:membrane_telemetry_metrics, "~> 0.1.0"},

      # HLS endpoints deps
      {:membrane_audio_mix_plugin, "~> 0.15.2"},
      {:membrane_video_compositor_plugin, "~> 0.5.1"},

      # Dialyzer and credo
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},

      # Load balancing
      {:libcluster, "~> 3.3"},
      {:httpoison, "~> 2.0"},

      # Test deps
      {:websockex, "~> 0.4.3", only: [:test, :ci], runtime: false},
      {:excoveralls, "~> 0.15.0", only: :test, runtime: false},
      {:divo, "~> 1.3.1", only: [:test, :ci]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "api.spec": &generate_api_spec/1,
      test: ["test --exclude cluster"],
      "test.cluster": ["test --only cluster"],
      "test.cluster.ci": ["cmd docker compose run test; docker compose stop"]
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

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/jellyfish-dev/jellyfish",
        "Membrane Framework Homepage" => "https://membrane.stream"
      }
    ]
  end

  defp generate_api_spec(_args) do
    output_filename = "openapi.yaml"
    generated_filename = "openapi-gen.yaml"

    Mix.shell().info("Generating #{output_filename}...")

    {_io_stream, exit_status} =
      System.cmd(
        "mix",
        ["openapi.spec.yaml", "--spec", "JellyfishWeb.ApiSpec", generated_filename],
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
