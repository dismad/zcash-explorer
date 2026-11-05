defmodule ZcashExplorer.Application do
  use Application
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      ZcashExplorerWeb.Telemetry,
      {Phoenix.PubSub, name: ZcashExplorer.PubSub},
      ZcashExplorerWeb.Endpoint,
      %{
        id: Zcashex,
        start:
          {Zcashex, :start_link,
           [
             Application.get_env(:zcash_explorer, Zcashex)[:zcashd_hostname],
             String.to_integer(Application.get_env(:zcash_explorer, Zcashex)[:zcashd_port]),
             Application.get_env(:zcash_explorer, Zcashex)[:zcashd_username],
             Application.get_env(:zcash_explorer, Zcashex)[:zcashd_password]
           ]}
      },
      {Cachex,
       name: :app_cache,
       warmers: [
         warmer(module: ZcashExplorer.Metrics.MetricsWarmer, state: {}),
         warmer(module: ZcashExplorer.Metrics.MempoolInfoWarmer, state: {}),
         warmer(module: ZcashExplorer.Metrics.NetworkSolpsWarmer, state: {}),
         warmer(module: ZcashExplorer.Nodes.NodeWarmer, state: {}),
         warmer(module: ZcashExplorer.Metrics.InfoWarmer, state: {})
       ]},
      # Reliable pollers — these keep looping after the first cycle
      ZcashExplorer.Blocks.BlockPoller,
      ZcashExplorer.Transactions.TransactionPoller,
      ZcashExplorer.Mempool.MempoolPoller
    ]

    opts = [strategy: :one_for_one, name: ZcashExplorer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    ZcashExplorerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
