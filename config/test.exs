use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :zcash_explorer, ZcashExplorer.Repo,
  username: "postgres",
  password: "postgres",
  database: "zcash_explorer_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: String.duplicate("test-secret-key-base-", 4),
  live_view: [signing_salt: "test-live-salt"]

# Print only warnings and errors during test
config :logger, level: :warn
