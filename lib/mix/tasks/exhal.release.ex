defmodule Mix.Tasks.ExHal.Release do
  @shortdoc "Release the hounds!"

  use Mix.Task
  alias Mix.Tasks.Hex.Build

  def run(_) do
    meta = Build.prepare_package()[:meta]

    System.cmd("git", ["tag", "v#{meta[:version]}"])
    System.cmd("git", ["push", "--tags"])

    Mix.Tasks.Hex.Publish.run([])
    Mix.Tasks.Hex.Publish.run(["docs"])
  end
end
