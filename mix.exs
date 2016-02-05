defmodule ExHal.Mixfile do
  use Mix.Project

  def project do
    [app: :exhal,
     description: "Use HAL APIs with ease",
     version: "2.1.0",
     elixir: "~> 1.0",

     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test],

     deps: deps,
     package: package]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:poison, "~>2.0"},
      {:uri_template, "~>1.0"},
      {:httpoison, "~> 0.8.0"},

      {:earmark, ">= 0.0.0", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},

      {:exvcr, "~> 0.7", only: :test},
      {:excoveralls, "~> 0.4", only: :test}
    ]
  end

  defp package do
    [ files: git_files,
      licenses: ["http://opensource.org/licenses/MIT"],
      maintainers: ["Peter Williams"],
      links: %{"homepage": "http://github.com/pezra/exhal"} ]
  end

  defp git_files do
    System.cmd("git", ["ls-files", "-z"])
      |> (fn {x,_} -> x end).()
      |> String.split(<<0>>)
      |> Enum.filter(fn x -> x != "" end)
  end

end
