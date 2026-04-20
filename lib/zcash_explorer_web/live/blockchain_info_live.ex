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

  defp sprout_value(value_pools), do: value_pools |> get_value_pools() |> Map.get("sprout", 0)
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
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- ===== EXACT SAME HEADER AS HOMELIVE ===== -->
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
