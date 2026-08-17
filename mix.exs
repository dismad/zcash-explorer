defmodule ZcashExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :zcash_explorer,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
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
      {:phoenix_view, "~> 2.0", override: true},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.11"},
      {:ecto, "~> 3.11"},
      {:postgrex, ">= 0.22.3"},
      {:ecto_psql_extras, "~> 0.8"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug, "~> 1.16"},
      {:plug_cowboy, "~> 2.7"},
      {:httpoison, "~> 1.8"},
      # {:hackney, "~> 4.7", override: true},
      # {:decimal, "~> 3.1", override: true},
      {:poison, "~> 3.1"},
      {:observer_cli, "~> 1.6"},
      {:cachex, "~> 3.3"},
      {:phoenix_live_view, "~> 0.20"},
      {:floki, ">= 0.27.0", only: :test},
      # ZSA support lives in this fork
      {:zcashex, github: "dismad/zcashex", branch: "zsa"},
      {:timex, "~> 3.0"},
      {:sizeable, "~> 1.0"},
      {:eqrcode, "~> 0.1.8"},
      {:contex, "~> 0.3.0"},
      {:muontrap, "~> 0.6.1"}
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
