defmodule ExHal.Mixfile do
  use Mix.Project

  def project do
    [app: :exhal,
     description: "Use HAL APIs with ease",
     version: "1.0.0",
     elixir: "~> 1.0",
     deps: deps,
     package: package]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:poison, "~>1.4"},
      {:uri_template, "~>1.0"},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp package do
    [ files: git_files,
      licenses: ["http://opensource.org/licenses/MIT"],
      contributors: ["Peter Williams"],
      links: %{"homepage": "http://github.com/pezra/exhal"} ]
  end

  defp git_files do
    System.cmd("git", ["ls-files", "-z"])
      |> (fn {x,_} -> x end).()
      |> String.split(<<0>>)
      |> Enum.filter(fn x -> x != "" end)
  end

end
