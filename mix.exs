defmodule PhoenixCgi.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_cgi,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:porcelain, "~> 2.0"},
      {:plug, "~> 1.10"}
    ]
  end

  defp aliases do
    []
  end
end
