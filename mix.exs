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
    [{:ejpet, git: "https://github.com/nmichel/ejpet.git"},
     {:ranch, git: "https://github.com/ninenines/ranch.git"},
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev}
    ]
  end
end
