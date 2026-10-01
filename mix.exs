defmodule Bizdays.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/igorgbr/bizdays"

  def project do
    [
      app: :bizdays,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Business day calculations with the Brazilian ANBIMA calendar.",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ["lib", "mix.exs", "README.md", "LICENSE"]
      ],
      source_url: @source_url,
      docs: [main: "readme", extras: ["README.md"], source_ref: "v#{@version}"]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false}
    ]
  end
end
