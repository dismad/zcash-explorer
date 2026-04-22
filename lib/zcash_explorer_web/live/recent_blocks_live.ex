defmodule ZcashExplorerWeb.RecentBlocksLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(_params, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    if connected?(socket), do: Process.send_after(self(), :update, 1000)

    case Cachex.get(:app_cache, "block_cache") do
      {:ok, info} ->
        {:ok, %{"chain" => chain}} = Cachex.get(:app_cache, "metrics")
        blocks_to_show = if standalone, do: info, else: Enum.take(info, 6)

        {:ok,
         assign(socket,
           block_cache: info,
           blocks_to_show: blocks_to_show,
           chain: chain,
           zcash_network: network,
           standalone: standalone
         )}

      _ ->
        {:ok,
         assign(socket,
           block_cache: [],
           blocks_to_show: [],
           chain: "main",
           zcash_network: network,
           standalone: standalone
         )}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 1000)
    {:ok, info} = Cachex.get(:app_cache, "block_cache")
    blocks_to_show = if socket.assigns.standalone, do: info, else: Enum.take(info, 12)

    {:noreply,
     assign(socket,
       block_cache: info,
       blocks_to_show: blocks_to_show
     )}
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
        <title>Recent Blocks - Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">
        <%= if @standalone do %>
          <!-- Full header only when visiting /blocks directly -->
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
        <% end %>

        <!-- New: Recent Blocks title + arrow + Block Radar link -->
        <div class="mx-auto px-6 pt-6 pb-3 flex items-center gap-x-3">
          
          
          

          <!-- Satellite icon + Block Radar link -->
          <a href="/block-radar" class="flex items-center gap-x-1.5 text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 transition-colors">
            <span class="text-xl">📡</span>
            <span class="font-medium">Block Radar</span>
          </a>
        </div>

        <!-- Table -->
        <div class="w-full">
          <div class="shadow overflow-hidden border-gray-200 rounded-lg overflow-x-auto">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3">Height</th>
                  <th scope="col" class="px-4 py-3">Hash</th>
                  <th scope="col" class="px-4 py-3">Mined on</th>
                  <th scope="col" class="px-4 py-3">Txns</th>
                  <th scope="col" class="px-4 py-3">Size</th>
                  <th scope="col" class="px-4 py-3">Output (<%= if @chain == "main", do: "ZEC", else: "TAZ" %>)</th>
                </tr>
              </thead>
              <tbody>
                <%= for block <- @blocks_to_show do %>
                  <tr class="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-indigo-600 hover:text-indigo-500 dark:text-white">
                      <a href={"/blocks/#{block["height"]}"}><%= block["height"] %></a>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap">
                      <a href={"/blocks/#{block["hash"]}"}><%= block["hash"] %></a>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap"><%= block["time"] %></td>
                    <td class="px-4 py-4 whitespace-nowrap"><%= block["tx_count"] %></td>
                    <td class="px-4 py-4 whitespace-nowrap"><%= block["size"] %></td>
                    <td class="px-4 py-4 whitespace-nowrap"><%= block["output_total"] %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </body>
    </html>
    """
  end
end