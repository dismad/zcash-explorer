defmodule ZcashExplorerWeb.HomeLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(_params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    {:ok, assign(socket, zcash_network: network)}
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
        <title>Zcash Explorer - Search the Zcash Blockchain</title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900 pb-20">
        <!-- ===== TOP BANNER (Logo only - super clean) ===== -->
        <header class="bg-gradient-to-r from-blue-950 via-blue-900 to-blue-800 text-white sticky top-0 z-50 shadow-md">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="h-14 flex items-center justify-between">
              <!-- Logo + Title -->
              <div class="flex items-center gap-x-3 flex-shrink-0">
                <a href="/" class="flex items-center">
                  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
                </a>
                <a href="/" class="text-xl font-semibold tracking-tight">Zcash Block Explorer</a>
              </div>
            </div>
          </div>
        </header>

        <!-- ===== SEARCH BAR ===== -->
        <div class="mx-auto px-4 sm:px-6 lg:px-8 py-5 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
          <div class="max-w-2xl mx-auto">
            <form action="/search" class="relative">
              <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 01-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <input
                name="qs"
                type="search"
                class="block w-full pl-11 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white dark:bg-gray-900 placeholder:text-gray-400 dark:placeholder:text-gray-500"
                placeholder="Search transactions, blocks, addresses..."
              >
            </form>
          </div>
        </div>

        <!-- ===== BOTTOM NAVIGATION (now visible on ALL screen sizes) ===== -->
        <nav class="fixed bottom-0 left-0 right-0 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 z-50 shadow-lg">
          <div class="max-w-7xl mx-auto grid grid-cols-5 text-xs">
            <a href="/mempool" class="flex flex-col items-center py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              <span class="font-medium">Mempool</span>
            </a>

            <!-- BLOCKS LINK WITH CUBE ICON -->
            <a href="/blocks" class="flex flex-col items-center py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-blue-600 dark:text-blue-400">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
                <line x1="12" y1="22.08" x2="12" y2="12"></line>
              </svg>
              <span class="font-medium">Blocks</span>
            </a>

            <!-- NEW: TRANSACTIONS LINK (right next to Blocks) -->
            <a href="/transactions" class="flex flex-col items-center py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
              </svg>
              <span class="font-medium">Txs</span>
            </a>

            <a href="/blockchain-info" class="flex flex-col items-center py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 4.01V8" />
              </svg>
              <span class="font-medium">Node</span>
            </a>

            <a href="/dev/rpc" class="flex flex-col items-center py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8 9l3 3-3 3m5 0h3M4 12a8 8 0 018-8 8 8 0 01-8 8z" />
              </svg>
              <span class="font-medium">RPCs</span>
            </a>
          </div>
        </nav>

        <!-- ===== MAIN CONTENT ===== -->
        <div class="mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="mb-12">
            <h2 class="text-2xl font-semibold mb-6 text-gray-900 dark:text-white">Recent Blocks</h2>
            <%= live_render(@socket, ZcashExplorerWeb.RecentBlocksLive, id: "recent-blocks", session: %{"standalone" => false}) %>
          </div>

          <div>
            <h2 class="text-2xl font-semibold mb-6 text-gray-900 dark:text-white">Recent Transactions</h2>
            <%= live_render(@socket, ZcashExplorerWeb.RecentTransactionsLive, id: "recent-transactions", session: %{"standalone" => false}) %>
          </div>
        </div>

        <!-- ===== FOOTER ===== -->
        <footer class="bg-gray-50 dark:bg-gray-900 isolate">
          <div class="max-w-7xl mx-auto py-12 px-4 overflow-hidden sm:px-6 lg:px-8">
            <nav class="-mx-5 -my-2 flex flex-wrap justify-center" aria-label="Footer">
              <div class="px-5 py-2">
                <a href="/privacy.html" class="text-base text-gray-500 hover:text-gray-900 dark:hover:text-slate-100">Privacy Policy</a>
              </div>
              <%= if @zcash_network != "testnet" do %>
                <div class="px-5 py-2">
                  <a href="https://testnet.zcashblockexplorer.com" class="text-base text-gray-500 hover:text-gray-900 dark:hover:text-slate-100">Testnet</a>
                </div>
                <div class="px-5 py-2">
                  <a href="http://zcashfgzdzxwiy7yq74uejvo2ykppu4pzgioplcvdnpmc6gcu5k6vwyd.onion/" class="text-base text-gray-500 hover:text-gray-900 dark:hover:text-slate-100">Onion V3</a>
                </div>
              <% else %>
                <div class="px-5 py-2">
                  <a href="https://zcashblockexplorer.com" class="text-base text-gray-500 hover:text-gray-900 dark:hover:text-slate-100">Mainnet</a>
                </div>
              <% end %>
            </nav>
            <p class="mt-8 text-center text-base text-gray-400">
              &copy; <%= DateTime.utc_now().year %>
              <a href="https://nighthawkapps.com/" target="_blank" rel="noreferrer">Nighthawk Apps</a>.
              <span class="block sm:inline">No tracker #Zcash Block Explorer.</span>
            </p>
          </div>
        </footer>
      </body>
    </html>
    """
  end
end