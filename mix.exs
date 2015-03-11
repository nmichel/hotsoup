defmodule Hotsoup.Mixfile do
  use Mix.Project

  def project do
    [app: :hotsoup,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
     deps: deps]
  end

  def application do
    [applications: [:logger],
     env: [backend: :jsx],
     mod: {Hotsoup, []}]
  end

  defp deps do
    [{:ejpet, git: "https://github.com/nmichel/ejpet.git"}]
  end
end
