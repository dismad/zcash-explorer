import Config

secret_key_base =
  case System.get_env("SECRET_KEY_BASE") do
    v when is_binary(v) and v != "" -> v
    _ ->
      raise """
      SECRET_KEY_BASE is missing.
      Add it to .env (openssl rand -base64 48) and start with ./dev.sh
      """
  end

config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: secret_key_base,
  live_view: [signing_salt: secret_key_base |> String.slice(0, 16)],
  watchers: [
  node: [
    "webpack.watch.js",
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

# Zebra + cookie authentication (safe version)
config :zcash_explorer, Zcashex,
  zcashd_hostname: System.get_env("ZCASHD_HOSTNAME", "localhost"),
  zcashd_port: System.get_env("ZCASHD_PORT", "8232"),
  zcash_network: System.get_env("ZCASH_NETWORK", "mainnet"),
  zcashd_username:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE", "/var/lib/zebrad-rpc/.cookie")

       case File.read(cookie_path) do
         {:ok, content} ->
           case String.trim(content) |> String.split(":", parts: 2) do
             ["__cookie__", _] -> "__cookie__"
             _ -> "__cookie__"
           end

         _ ->
           # No Logger here — config runs before the app logger is ready
           "__cookie__"
       end
     end).(),
  zcashd_password:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE", "/var/lib/zebrad-rpc/.cookie")

       case File.read(cookie_path) do
         {:ok, content} ->
           case String.trim(content) |> String.split(":", parts: 2) do
             ["__cookie__", pass] -> pass
             _ -> ""
           end

         _ ->
           ""
       end
     end).() 
