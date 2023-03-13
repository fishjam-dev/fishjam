defmodule Jellyfish.MixProject do
  use Mix.Project

  def project do
    [
      app: :jellyfish,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
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
        "coveralls.json": :test
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
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.15"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:uuid, "~> 1.1"},
      {:cors_plug, "~> 3.0"},
      {:open_api_spex, "~> 3.16"},
      {:ymlr, "~> 3.0"},

      # Membrane deps
      {:membrane_rtc_engine, github: "jellyfish-dev/membrane_rtc_engine"},

      # HLS endpoints deps
      {:membrane_aac_plugin, "~> 0.13.0"},
      {:membrane_opus_plugin, "~> 0.16.0"},
      {:membrane_aac_fdk_plugin, "~> 0.14.0"},
      {:membrane_generator_plugin, "~> 0.8.0"},
      {:membrane_realtimer_plugin, "~> 0.6.0"},
      {:membrane_audio_mix_plugin, "~> 0.12.0"},
      {:membrane_raw_audio_format, "~> 0.10.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.25.2"},
      {:membrane_audio_filler_plugin, "~> 0.1.0"},
      {:membrane_video_compositor_plugin, "~> 0.2.1"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.11.0"},

      # Dialyzer and credo
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},

      # Test deps
      {:excoveralls, "~> 0.15.0", only: :test, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
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
end
