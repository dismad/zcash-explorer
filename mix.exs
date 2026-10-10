defmodule ZcashExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :zcash_explorer,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {ZcashExplorer.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :cachex]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.15"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.14"},
      {:ecto, "~> 3.14"},
      {:postgrex, "~> 0.22.4"},
      {:ecto_psql_extras, "~> 0.8"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2.12"},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:telemetry_metrics, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0", override: true},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.20"},
      {:plug_cowboy, "~> 2.9"},
      {:hackney, "~> 4.5", override: true},
      {:httpoison, "~> 3.0", override: true},
      {:observer_cli, "~> 1.8"},
      {:cachex, "~> 4.1"},
      {:floki, ">= 0.38.4", only: :test},
      # Ironwood support lives in this fork
      {:zcashex, github: "dismad/zcashex", branch: "main"},
      {:timex, "~> 3.7"},
      {:sizeable, "~> 1.0"},
      {:eqrcode, "~> 0.2"},
      {:contex, "~> 0.5"},
      {:muontrap, "~> 1.8"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
