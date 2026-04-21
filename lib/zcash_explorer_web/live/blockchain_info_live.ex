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
