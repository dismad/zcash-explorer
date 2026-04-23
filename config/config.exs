# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

# General application configuration
config :zcash_explorer,
  ecto_repos: [ZcashExplorer.Repo]

# Configures the endpoint
config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: System.get_env("SECRET_KEY_BASE") ||
                   raise("""
                   environment variable SECRET_KEY_BASE is missing.
                   You can generate one by calling: mix phx.gen.secret
                   """),
  render_errors: [view: ZcashExplorerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: ZcashExplorer.PubSub,
  live_view: [signing_salt: System.get_env("SIGNING_SALT") ||
              raise("environment variable SIGNING_SALT is missing.")]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"