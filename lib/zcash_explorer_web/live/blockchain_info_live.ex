defmodule ZcashExplorerWeb.BlockChainInfoLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 5000)

    # Assign network so the header works exactly like HomeLive
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    case Cachex.get(:app_cache, "metrics") do
      {:ok, info} ->
        {:ok, %{"build" => build}} = Cachex.get(:app_cache, "info")
        info = Map.put(info, "build", build)
        currency = if info["chain"] == "main", do: "ZEC", else: "TAZ"
        {:ok, assign(socket, blockchain_info: info, currency: currency, zcash_network: network)}

      {:error, _reason} ->
        {:ok, assign(socket, blockchain_info: %{}, currency: "ZEC", zcash_network: network)}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)

    {:ok, info} = Cachex.get(:app_cache, "metrics")
    {:ok, %{"build" => build}} = Cachex.get(:app_cache, "info")
    info = Map.put(info, "build", build)

    currency = if info["chain"] == "main", do: "ZEC", else: "TAZ"

    {:noreply, assign(socket, blockchain_info: info, currency: currency)}
  end

  defp sprout_value(value_pools),  do: value_pools |> get_value_pools() |> Map.get("sprout", 0)
  defp sapling_value(value_pools), do: value_pools |> get_value_pools() |> Map.get("sapling", 0)
  defp orchard_value(value_pools), do: value_pools |> get_value_pools() |> Map.get("orchard", 0)

  defp get_value_pools(value_pools) do
    Enum.map(value_pools, fn %{"id" => name, "chainValue" => value} -> {name, value} end)
    |> Map.new()
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
        <title>Blockchain Information - Zcash Explorer</title>
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- ===== EXACT SAME HEADER AS HOMELIVE ===== -->
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
                      <div class="shrink-0 px-1 text-white dark:text-white md:block lg:block xl:block 2xl:block hidden">
                        Zcash Testnet Block Explorer
                      </div>
                    <% else %>
                      <div class="shrink-0 px-1 text-white dark:text-white md:block lg:block xl:block 2xl:block hidden">
                        Zcash Block Explorer
                      </div>
                    <% end %>
                  </a>
                </div>

                <!-- Search bar -->
                <div class="flex-1 flex justify-center lg:justify-end">
                  <div class="w-full px-2 lg:px-6 max-w-md">
                    <form action="/search" method="get">
                      <div class="relative text-gray-200 dark:text-slate-200 focus-within:text-gray-400">
                        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 01-14 0 7 7 0 0114 0z" />
                          </svg>
                        </div>
                        <input type="text" name="q" placeholder="transaction / block / address" 
                               class="block w-full pl-10 pr-3 py-2 border border-transparent rounded-md leading-5 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:bg-white dark:focus:bg-gray-600 focus:ring-0">
                      </div>
                    </form>
                  </div>
                </div>

                <!-- Desktop nav -->
                <div class="hidden lg:flex items-center space-x-8 text-white text-sm font-medium">
                  <a href="/mempool" class="hover:text-indigo-200">Mempool</a>
                  <a href="/blocks" class="hover:text-indigo-200">Blocks</a>
                  <a href="/nodes" class="hover:text-indigo-200">Nodes</a>
                  <a href="/broadcast" class="hover:text-indigo-200">Broadcast</a>
                  <a href="/vk" class="hover:text-indigo-200">Viewing Key</a>
                </div>

                <!-- Mobile menu button -->
                <div class="lg:hidden">
                  <button @click="open = !open" class="text-white p-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                    </svg>
                  </button>
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

        <!-- Page content (your original stats) -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <h1 class="text-3xl font-semibold text-gray-900 dark:text-white mb-8">Blockchain Information</h1>

          <dl class="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-3">
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Blocks</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= @blockchain_info["blocks"] || "—" %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Commitments</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= @blockchain_info["commitments"] || "—" %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Difficulty</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= @blockchain_info["difficulty"] || "—" %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Sprout pool</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= sprout_value(@blockchain_info["valuePools"]) %> <%= @currency %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Sapling pool</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= sapling_value(@blockchain_info["valuePools"]) %> <%= @currency %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Orchard pool</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= orchard_value(@blockchain_info["valuePools"]) %> <%= @currency %></dd>
            </div>
            <div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 dark:bg-gray-800">
              <dt class="text-sm font-medium text-gray-500 truncate">Zebra version</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= @blockchain_info["build"] || "—" %></dd>
            </div>
          </dl>
        </div>
      </body>
    </html>
    """
  end
end