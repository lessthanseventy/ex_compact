defmodule ExCompact.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ex_compact,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: ExCompact.CLI],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExCompact.Application, []}
    ]
  end

  defp deps do
    [
      {:igniter, "~> 0.7", only: [:dev]},
      {:usage_rules, "~> 1.1", only: [:dev]},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      description: "Compact noisy BEAM output for Claude Code",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/youruser/ex_compact"},
      files: ~w(lib hooks mix.exs README.md LICENSE usage-rules.md usage-rules)
    ]
  end
end
