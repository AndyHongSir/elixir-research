defmodule Wt.Mixfile do
  use Mix.Project

  def project do
    [
      app: :wt,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5.1",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger,:nerves_uart,:amqp,:json,:ok,:tirexs,:elastex],
      mod: {WT, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
  ##{:maru, "~> 0.10"},
      {:nerves_uart, "~> 0.1.2"},
      {:json,"~> 1.0.2"},
      {:amqp, "~> 0.2.1"},
      {:ok,"~> 1.6"},{:tirexs,"~>0.8"},
      {:elixir_ale, "~> 1.0"},
      {:elastex, git: "https://github.com/meivantodorov/elastex.git", tag: "master"}
    ]
  end
end
