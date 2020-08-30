defmodule PhoenixCgi.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_cgi,
      name: "PhoenixCGI",
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      source_url: "https://github.com/publica-re/phoenix_cgi",
      package: package()
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:porcelain, "~> 2.0"},
      {:plug, "~> 1.10"}
    ]
  end

  defp aliases do
    []
  end

  defp package() do
    [
      name: "phoenix_cgi",
      description: "A small CGI controller for Phoenix",
      licenses: ["GPL-3.0-or-later"],
      links: %{"GitHub" => "https://github.com/publica-re/phoenix_cgi", "Author" => "https://publica.re"}
    ]
  end
end
