defmodule ExHal.Mixfile do
  use Mix.Project

  def project do
    [app: :exhal,
     description: "Use HAL APIs with ease",
     version: "5.3.0",
     elixir: "~> 1.3",

     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test,
                         "coveralls.detail": :test,
                         "coveralls.post": :test],

     deps: deps(),
     package: package()]
  end

  def application do
    [applications: [:logger, :poison, :uri_template, :httpoison]]
  end

  defp deps do
    [
      {:poison, "~> 2.2 or ~> 3.0"},
      {:uri_template, "~> 1.0"},
      {:httpoison, "~> 0.11.0"},

      {:earmark, ">= 0.0.0", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
      {:dialyxir, "~> 0.3", only: :dev},

      {:exvcr, "~> 0.7", only: :test},
      {:excoveralls, "~> 0.4", only: :test}
    ]
    |> dep_version_overrides
  end

  defp package do
    [ files: git_files() -- excluded_files(),
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

  defp excluded_files do
    [ "lib/mix/tasks/release.ex" ]
  end

  # For testing with continuous integration systems, it is possible to force
  # the dependency version on packages for which we allow more than one version.
  #
  # For example, say we want to test with two versions of the 'ExWidget' package.
  # The deps may look like this:
  # defp deps do
  #   [ ..., {:ex_widget, "~> 1.5 or ~> 2.2"}, ... ]
  # end
  #
  # Step 1: Add :ex_widget to the @overridable_deps list (below)
  # Step 2: Set the environment variable EXHAL_EX_WIDGET_VERSION before compiling, e.g.
  #   EXHAL_EX_WIDGET_VERSION=2.2.3 mix do deps.get, deps.compile
  #   EXHAL_EX_WIDGET_VERSION="~> 1.5" mix do deps.get, deps.comile

  @overridable_deps [:poison]
  defp dep_version_overrides(deps_list) do
    @overridable_deps
    |> Enum.map(&({&1, env_var_value_for_dep(&1)}))
    |> Enum.reduce(deps_list, &override_dep/2)
  end

  defp env_var_value_for_dep(dep_atom) do
    dep_str = dep_atom |> Atom.to_string |> String.upcase
    System.get_env("EXHAL_#{dep_str}_VERSION")
  end

  defp override_dep({_package, nil}, deps_list), do: deps_list
  defp override_dep({package, version}, deps_list) do
    Enum.reject(deps_list, fn(dep) -> elem(dep, 0) == package end) ++
      [{package, version}]
  end

end
