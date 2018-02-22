defmodule SeventeenMon.Mixfile do
  use Mix.Project

  def project do
    [
      app: :seventeen_mon,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :cachex],
      mod: {SeventeenMon, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 0.12", only: :dev},
      {:cachex, "~> 3.0"}
    ]
  end
end
