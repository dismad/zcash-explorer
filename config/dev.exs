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
    cd: Path.expand("../assets", __DIR__),
    env: [{"NODE_OPTIONS", "--openssl-legacy-provider"}]
  ],
  npm: [
    "run",
    "watch:css",
    cd: Path.expand("../assets", __DIR__)
  ]
]

config :zcash_explorer, Zcashex,
  zcashd_hostname: "localhost",
  zcashd_port: "8232",
  zcashd_username:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE", "/var/lib/zebrad-rpc/.cookie")

       case File.read(cookie_path) do
         {:ok, content} ->
           case String.trim(content) |> String.split(":", parts: 2) do
             ["__cookie__", _] -> "__cookie__"
             _ -> "nighthawkapps"
           end

         _ ->
           "nighthawkapps"
       end
     end).(),
  zcashd_password:
    (fn ->
       cookie_path = System.get_env("ZCASH_RPC_COOKIE_FILE", "/var/lib/zebrad-rpc/.cookie")

       case File.read(cookie_path) do
         {:ok, content} ->
           case String.trim(content) |> String.split(":", parts: 2) do
             ["__cookie__", pass] -> pass
             _ -> "ffwf"
           end

         _ ->
           "ffwf"
       end
     end).(),
  vk_cpus: "0.2",
  vk_mem: "2048M",
  vk_runnner_image: "nighthawkapps/vkrunner",
  zcash_network: "mainnet"
