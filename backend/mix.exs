defmodule Uno.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :uno,
      version: "1.0.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]

  def application, do: [extra_applications: [:logger, :crypto], mod: {Uno.Application, []}]
  defp deps, do: [{:phoenix, "~> 1.8.0"}, {:bandit, "~> 1.5"}, {:jason, "~> 1.4"}]
end
