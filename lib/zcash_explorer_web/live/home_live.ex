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
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- ===== HEADER (your exact current header) ===== -->
        <header class="bg-indigo-600 text-white h-14 flex items-center">
	  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
	    <div class="flex items-center justify-between h-full">
	      
	      <!-- Logo + Title -->
	      <div class="flex items-center gap-x-3 flex-shrink-0">
		<a href="/" class="flex items-center">
		  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
		</a>
		<a href="/" class="text-xl font-semibold tracking-tight">Zcash Block Explorer</a>
	      </div>

	      <!-- Search Bar -->
	      <div class="flex-1 max-w-2xl mx-8 mt-4">
		<form action="/search" class="relative">
		  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
		    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
		      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 01-14 0 7 7 0 0114 0z" />
		    </svg>
		  </div>
		  <input 
		    name="qs" 
		    type="search"
		    class="block w-full pl-11 pr-4 py-2.5 bg-white/20 hover:bg-white/30 focus:bg-white focus:text-gray-900 placeholder:text-white/70 text-white rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-white/50 transition-all"
		    placeholder="transaction / block / address"
		  >
		</form>
	      </div>

	      <!-- Desktop Navigation -->
	      <div class="hidden lg:flex items-center gap-x-8 text-sm font-medium flex-shrink-0">
		<a href="/mempool" class="hover:text-white/80 transition-colors">Mempool</a>
		<a href="/blocks" class="hover:text-white/80 transition-colors">Blocks</a>
		<a href="/nodes" class="hover:text-white/80 transition-colors">Nodes</a>
		<a href="/broadcast" class="hover:text-white/80 transition-colors">Broadcast</a>
		<%= if @zcash_network != "testnet" do %>
		  <a href="/vk" class="hover:text-white/80 transition-colors">Viewing Key</a>
		<% end %>
	      </div>
	    </div>
	  </div>
	</header>

        <!-- ===== MAIN CONTENT WITH ALL 4 CARDS ===== -->
        <div class="grid gap-4 grid-cols-1 mx-8 py-5">
          <!-- 4 Cards -->
          <div class="grid gap-5 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4">
            <!-- Orchard Pool -->
            <div class="relative bg-white pt-5 px-4 pb-12 sm:pt-6 sm:px-6 shadow rounded-lg overflow-hidden dark:bg-gray-800">
              <dt>
                <div class="absolute bg-green-500 rounded-md p-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <p class="ml-16 text-sm font-medium text-gray-500 truncate">Orchard Pool</p>
              </dt>
              <dd class="ml-16 pb-6 flex items-baseline sm:pb-7">
                <div class="text-3xl font-semibold whitespace-nowrap">
                  <%= live_render(@socket, ZcashExplorerWeb.OrchardPoolLive, id: "orchard-pool") %>
                </div>
              </dd>
              <div class="absolute bottom-0 inset-x-0 bg-gray-50 px-4 py-4 sm:px-6 dark:bg-gray-700">
                <a href="/blockchain-info" class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-white dark:hover:text-slate-50">View blockchain info →</a>
              </div>
            </div>

            <!-- Blocks -->
            <div class="relative bg-white pt-5 px-4 pb-12 sm:pt-6 sm:px-6 shadow rounded-lg overflow-hidden dark:bg-gray-800">
              <dt>
                <div class="absolute bg-green-500 rounded-md p-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2" />
                  </svg>
                </div>
                <p class="ml-16 text-sm font-medium text-gray-500 truncate">Blocks</p>
              </dt>
              <dd class="ml-16 pb-6 flex items-baseline sm:pb-7">
                <div class="text-3xl font-semibold whitespace-nowrap">
                  <%= live_render(@socket, ZcashExplorerWeb.BlockCountLive, id: "block-count") %>
                </div>
              </dd>
              <div class="absolute bottom-0 inset-x-0 bg-gray-50 px-4 py-4 sm:px-6 dark:bg-gray-700">
                <a href="/blocks" class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-white dark:hover:text-slate-50">View blocks →</a>
              </div>
            </div>

            <!-- Mempool Transactions -->
            <div class="relative bg-white pt-5 px-4 pb-12 sm:pt-6 sm:px-6 shadow rounded-lg overflow-hidden dark:bg-gray-800">
              <dt>
                <div class="absolute bg-violet-500 rounded-md p-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <p class="ml-16 text-sm font-medium text-gray-500 truncate">Mempool Transactions</p>
              </dt>
              <dd class="ml-16 pb-6 flex items-baseline sm:pb-7">
                <div class="text-3xl font-semibold whitespace-nowrap">
                  <%= live_render(@socket, ZcashExplorerWeb.MempoolInfoLive, id: "mempool-info", session: %{"standalone" => false}) %>
                </div>
              </dd>
              <div class="absolute bottom-0 inset-x-0 bg-gray-50 px-4 py-4 sm:px-6 dark:bg-gray-700">
                <a href="/mempool" class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-white dark:hover:text-slate-50">View mempool transactions →</a>
              </div>
            </div>

            <!-- Blockchain Size -->
            <div class="relative bg-white pt-5 px-4 pb-12 sm:pt-6 sm:px-6 shadow rounded-lg overflow-hidden dark:bg-gray-800">
              <dt>
                <div class="absolute bg-green-500 rounded-md p-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10" />
                  </svg>
                </div>
                <p class="ml-16 text-sm font-medium text-gray-500 truncate">Blockchain Size</p>
              </dt>
              <dd class="ml-16 pb-6 flex items-baseline sm:pb-7">
                <div class="text-3xl font-semibold whitespace-nowrap">
                  <%= live_render(@socket, ZcashExplorerWeb.BlockChainSizeLive, id: "blockchain-size") %>
                </div>
              </dd>
              <div class="absolute bottom-0 inset-x-0 bg-gray-50 px-4 py-4 sm:px-6 dark:bg-gray-700">
                <a href="/blockchain-info" class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-white dark:hover:text-slate-50">View blockchain info →</a>
              </div>
            </div>
          </div>

          <!-- Recent Blocks -->
          <div class="mb-12">
            <h2 class="text-2xl font-semibold mb-6 text-gray-900 dark:text-white">Recent Blocks</h2>
            <%= live_render(@socket, ZcashExplorerWeb.RecentBlocksLive, id: "recent-blocks", session: %{"standalone" => false}) %>
          </div>

          <!-- Recent Transactions -->
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

            <div class="mt-8 flex justify-center space-x-6">
              <!-- Twitter and GitHub links can go here if you want them -->
            </div>

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