defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      app: :app,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {App.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {
        :hidraw,
        git: "https://github.com/krodelin/hidraw.git",
        tag: "v0.2.1-u1"
      },
      {:usb_gadget, git: "https://github.com/nerves-project/usb_gadget.git"},
      {:sshex, "2.2.1"},
    ]
  end
end
