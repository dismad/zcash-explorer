import Config

config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.get_env("SIGNING_SALT")],
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ],
    npm: [
      "run",
      "watch:css",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# Crosslink / zebra-crosslink RPC config
# Cookie auth is disabled on your node (enable_cookie_auth = false)
config :zcash_explorer, Zcashex,
  zcashd_hostname: System.get_env("ZCASHD_HOSTNAME", "127.0.0.1"),
  zcashd_port: System.get_env("ZCASHD_PORT", "8232"),
  zcash_network: System.get_env("ZCASH_NETWORK", "testnet"),
  zcashd_username:
    (fn ->
      cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE")

      if cookie_path in [nil, ""] do
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