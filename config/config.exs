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
# config/dev.exs

config :zcash_explorer, Zcashex,
  zcashd_hostname: System.get_env("ZCASHD_HOSTNAME", "127.0.0.1"),
  zcashd_port: System.get_env("ZCASHD_PORT", "8232"),
  zcash_network: System.get_env("ZCASH_NETWORK", "testnet"),
  zcashd_username:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE")

       if cookie_path in [nil, ""] do
         # Cookie auth disabled (common on crosslink feature nets)
         ""
       else
         case File.read(cookie_path) do
           {:ok, content} ->
             case String.trim(content) |> String.split(":", parts: 2) do
               ["__cookie__", _] -> "__cookie__"
               [user, _] -> user
               _ -> ""
             end

           _ ->
             ""
         end
       end
     end).(),
  zcashd_password:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE")

       if cookie_path in [nil, ""] do
         ""
       else
         case File.read(cookie_path) do
           {:ok, content} ->
             case String.trim(content) |> String.split(":", parts: 2) do
               ["__cookie__", pass] -> pass
               [_, pass] -> pass
               _ -> ""
             end

           _ ->
             ""
         end
       end
     end).()
# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"