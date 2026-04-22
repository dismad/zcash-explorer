defmodule ZcashExplorerWeb.Router do
  use ZcashExplorerWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ZcashExplorerWeb do
    pipe_through :browser

    # Main pages – all LiveView
    live "/", HomeLive
    live "/blocks", RecentBlocksLive
    live "/blocks/:hash", BlockLive
    live "/transactions", RecentTransactionsLive
    live "/transactions/:txid", TransactionLive
    live "/blockchain-info", BlockChainInfoLive
    live "/mempool", RawMempoolLive
    live "/nodes", NodesLive
    live "/broadcast", BroadcastLive
    live "/vk", VkLive
    live "/block-radar", BlockRadarLive, :index

    # Shielded addresses (z1..., zs1..., u1...) — single LiveView
    live "/shielded/:address", ShieldedAddressLive
    live "/ua/:address", ShieldedAddressLive

    # Metric / helper LiveViews
    live "/price", PriceLive
    live "/metrics/difficulty", DifficultyLive
    live "/metrics/block_count", BlockCountLive
    live "/metrics/blockchain_size", BlockChainSizeLive
    live "/metrics/mempool_info", MempoolInfoLive
    live "/metrics/networksolps", NetworkSolpsLive
    live "/live/raw_mempool", RawMempoolLive
    live "/live/orchard_pool", OrchardPoolLive
    live "/dev/rpc", RpcDiscoverLive

    # Search and Address pages
    get "/search", SearchController, :search
    live "/address/:address", AddressLive

    post "/broadcast", PageController, :do_broadcast
    get "/payment-disclosure", PageController, :disclosure
    post "/payment-disclosure", PageController, :do_disclosure
    post "/vk", PageController, :do_import_vk

    # API routes
    get "/transactions/:txid/raw", TransactionController, :get_raw_transaction
  end

  scope "/", ZcashExplorerWeb do
    pipe_through :api
    get "/api/v1/blockchain-info", PageController, :blockchain_info_api
    get "/api/v1/supply", PageController, :supply
    post "/api/vk/:hostname", PageController, :vk_from_zecwalletcli
  end

  # LiveDashboard (development only)
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router
    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard",
        metrics: ZcashExplorerWeb.Telemetry,
        ecto_repos: [ZcashExplorer.Repo]
    end
  end
end