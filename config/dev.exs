import Config

config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
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
