defmodule ZcashExplorerWeb.TransactionLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(%{"txid" => txid}, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx} ->
        tx_data = Zcashex.Transaction.from_map(tx)
        {:ok, assign(socket, tx: tx_data, txid: txid, zcash_network: network)}

      {:error, reason} ->
        {:ok, assign(socket, error: reason, txid: txid, zcash_network: network)}
    end
  end

  # ── Local helpers (replacing old View modules) ──
  defp mined_time(timestamp) when is_integer(timestamp) do
    Timex.from_unix(timestamp) |> Timex.format!("{relative}", :relative)
  rescue
    _ -> "—"
  end

  defp format_zec(amount) when is_number(amount) do
    amount
    |> Decimal.new()
    |> Decimal.div(100_000_000)
    |> Decimal.to_string(:normal, 8)
  rescue
    _ -> "0.00000000"
  end

  # Simple tx type detection (expand if needed)
  defp tx_type(tx) do
    cond do
      length(tx.vin) > 0 && hd(tx.vin).coinbase != nil -> "coinbase"
      length(tx.vShieldedSpend) > 0 && length(tx.vShieldedOutput) > 0 -> "shielded"
      length(tx.vShieldedSpend) > 0 -> "deshielding"
      length(tx.vShieldedOutput) > 0 -> "shielding"
      true -> "transparent"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Transaction <%= @txid %> - Zcash Explorer</title>
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- Full header -->
        <header>
          <nav x-data="{ open: false }" class="shrink-0 bg-indigo-600 dark:bg-gray-800">
            <div class="max-w-7xl mx-auto px-2 sm:px-4 lg:px-8">
              <div class="relative flex items-center justify-between h-16">
                <!-- Logo -->
                <div class="flex items-center px-2 lg:px-0 xl:w-64">
                  <a href="/">
                    <div class="shrink-0">
                      <img class="h-8 w-auto" src="/images/zcash-icon-white.svg" alt="Zcash Block Explorer">
                    </div>
                  </a>
                  <a href="/">
                    <%= if @zcash_network == "testnet" do %>
                      <div class="shrink-0 px-1 text-white dark:text-white md:block lg:block xl:block 2xl:block hidden">Zcash Testnet Block Explorer</div>
                    <% else %>
                      <div class="shrink-0 px-1 text-white dark:text-white md:block lg:block xl:block 2xl:block hidden">Zcash Block Explorer</div>
                    <% end %>
                  </a>
                </div>

                <!-- Search -->
                <div class="flex-1 flex justify-center lg:justify-end">
                  <div class="w-full px-2 lg:px-6">
                    <form action="/search">
                      <div class="relative text-gray-200 dark:text-slate-200 focus-within:text-gray-400 dark:focus-within:text-slate-800">
                        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                          </svg>
                        </div>
                        <input name="qs" class="block w-full pl-10 pr-3 py-2 border border-transparent rounded-md leading-5 text-indigo-100 placeholder-indigo-200 focus:outline-none focus:bg-white focus:ring-0 focus:placeholder-gray-400 focus:text-gray-900 sm:text-sm dark:focus:placeholder-white dark:border-slate-600 dark:placeholder-slate-400 dark:text-white dark:focus:ring-slate-500 dark:focus:border-slate-500 dark:hover:bg-slate-700 dark:focus:ring-slate-800 bg-white/25 dark:bg-slate-700 dark:focus:bg-slate-600 dark:placeholder-slate-200 dark:focus:text-gray-200" placeholder="transaction / block / address" type="search">
                      </div>
                    </form>
                  </div>
                </div>

                <!-- Desktop nav -->
                <div class="hidden lg:block lg:w-80 z-40">
                  <div class="flex items-center justify-end">
                    <a href="/mempool" class="px-3 py-2 rounded-md text-sm font-medium text-indigo-200 hover:text-white dark:text-gray-400">Mempool</a>
                    <a href="/blocks" class="px-3 py-2 rounded-md text-sm font-medium text-indigo-200 hover:text-white dark:text-gray-400">Blocks</a>
                    <a href="/nodes" class="px-3 py-2 rounded-md text-sm font-medium text-indigo-200 hover:text-white dark:text-gray-400">Nodes</a>
                    <a href="/broadcast" class="px-3 py-2 rounded-md text-sm font-medium text-indigo-200 hover:text-white dark:text-gray-400">Broadcast</a>
                    <a href="/vk" class="px-3 py-2 rounded-md text-sm font-medium text-indigo-200 hover:text-white dark:text-gray-400">Viewing Key</a>
                  </div>
                </div>
              </div>
            </div>

            <!-- Mobile menu -->
            <div x-show="open" class="lg:hidden bg-indigo-700 dark:bg-gray-900 px-2 pt-2 pb-3">
              <a href="/mempool" class="block px-3 py-2 text-white hover:bg-indigo-600 rounded-md">Mempool</a>
              <a href="/blocks" class="block px-3 py-2 text-white hover:bg-indigo-600 rounded-md">Blocks</a>
              <a href="/nodes" class="block px-3 py-2 text-white hover:bg-indigo-600 rounded-md">Nodes</a>
              <a href="/broadcast" class="block px-3 py-2 text-white hover:bg-indigo-600 rounded-md">Broadcast Transaction</a>
              <a href="/vk" class="block px-3 py-2 text-white hover:bg-indigo-600 rounded-md">Viewing Key</a>
            </div>
          </nav>
        </header>

        <!-- Transaction Details Content (ported from your old tx.html.heex) -->
        <main class="py-4 lg:px-12">
          <div class="grid gap-4 mx-2 grid-cols-1 md:mx-8">
            <div class="space-y-6 lg:col-start-1 lg:col-span-2">
              <section aria-labelledby="block-details-title">
                <div class="bg-white shadow rounded-lg dark:bg-gray-800">
                  <div class="px-4 py-5 sm:px-6">
                    <h2 id="block-details-title" class="text-lg leading-6 font-medium text-gray-900 inline-block break-words dark:text-gray-50">
                      Details for the Zcash Transaction ID
                    </h2>
                    <h2 class="md:inline-block text-gun-powder-500 break-words dark:text-gray-200"><%= @tx.txid %></h2>
                  </div>

                  <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
                    <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
                      <div class="sm:col-span-1">
                        <dt class="text-sm font-medium text-gray-500">Confirmations</dt>
                        <dd class="mt-1 text-xl font-semibold text-gray-900 dark:text-gray-50"><%= if @tx.confirmations == nil, do: 0, else: @tx.confirmations %></dd>
                      </div>
                      <div class="sm:col-span-1">
                        <dt class="text-sm font-medium text-gray-500">Time (UTC)</dt>
                        <dd class="mt-1 text-sm text-gray-900 dark:text-gray-50"><%= mined_time(@tx.time) %></dd>
                      </div>
                      <div class="sm:col-span-1">
                        <dt class="text-sm font-medium text-gray-500">Tx Type</dt>
                        <dd class="mt-1 text-sm text-gray-900">
                          <%= case tx_type(@tx) do %>
                            <% "coinbase" -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-yellow-400 text-gray-900 capitalize">💰 Coinbase</span>
                            <% "shielded" -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-green-200 text-gray-900 capitalize">🛡 Shielded</span>
                            <% "transparent" -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-red-200 text-gray-900 capitalize">🔍 Public</span>
                            <% "shielding" -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-red-50 text-gray-900 capitalize">Shielding (T-Z)</span>
                            <% "deshielding" -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-red-50 text-gray-900 capitalize">Deshielding (Z-T)</span>
                            <% _ -> %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-s font-medium bg-gray-200 text-gray-900 capitalize">Unknown</span>
                          <% end %>
                        </dd>
                      </div>
                      <!-- Add more fields from your old template here as needed -->
                    </dl>
                  </div>
                </div>
              </section>
            </div>
          </div>
        </main>
      </body>
    </html>
    """
  end
end