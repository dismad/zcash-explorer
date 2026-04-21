defmodule ZcashExplorerWeb.RecentTransactionsLive do
  use Phoenix.LiveView, layout: false
  # ← This fixes the "raw/1" error
  import Phoenix.HTML
  import ZcashExplorerWeb.TransactionHelper

  @impl true
  def mount(_params, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    if connected?(socket), do: Process.send_after(self(), :update, 1000)

    case Cachex.get(:app_cache, "transaction_cache") do
      {:ok, info} ->
        {:ok, %{"chain" => chain}} = Cachex.get(:app_cache, "metrics")
        txs_to_show = if standalone, do: info, else: Enum.take(info, 12)

        {:ok,
         assign(socket,
           transaction_cache: info,
           txs_to_show: txs_to_show,
           chain: chain,
           zcash_network: network,
           standalone: standalone
         )}

      _ ->
        {:ok,
         assign(socket,
           transaction_cache: [],
           txs_to_show: [],
           chain: "main",
           zcash_network: network,
           standalone: standalone
         )}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 1000)
    {:ok, info} = Cachex.get(:app_cache, "transaction_cache")
    txs_to_show = if socket.assigns.standalone, do: info, else: Enum.take(info, 12)

    {:noreply,
     assign(socket,
       transaction_cache: info,
       txs_to_show: txs_to_show
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
        <title>Recent Transactions - Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">
        <%= if @standalone do %>
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

        <div class="w-full">
          <div class="shadow overflow-hidden border-gray-200 rounded-lg overflow-x-auto">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3">Transaction ID</th>
                  <th scope="col" class="px-6 py-3">Block#</th>
                  <th scope="col" class="px-6 py-3">Time (UTC)</th>
                  <th scope="col" class="px-6 py-3">Public Output (<%= if @chain == "main", do: "ZEC", else: "TAZ" %>)</th>
                  <th scope="col" class="px-4 py-3">TX Type</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200 dark:bg-gray-800 dark:divide-gray-700">
                <%= for tx <- @txs_to_show do %>
                  <tr class="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-indigo-600 hover:text-indigo-500 dark:text-white">
                      <a href={"/transactions/#{tx["txid"]}"}><%= tx["txid"] %></a>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <a href={"/blocks/#{tx["block_height"]}"}><%= tx["block_height"] %></a>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium"><%= tx["time"] %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium"><%= tx["tx_out_total"] %> ZEC</td>
                    <td class="px-4 py-4 whitespace-nowrap">
                      <%= if match?({:safe, _}, tx["type"]) do %>
                        <%= raw(elem(tx["type"], 1)) %>
                      <% else %>
                        <%= tx_type(tx) %>
                      <% end %>
                    </td>
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
