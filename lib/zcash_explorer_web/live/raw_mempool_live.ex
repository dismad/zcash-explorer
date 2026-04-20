defmodule ZcashExplorerWeb.RawMempoolLive do
  use Phoenix.LiveView, layout: false
  import Phoenix.HTML
  import ZcashExplorerWeb.TransactionHelper

  @impl true
  def mount(_params, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    if connected?(socket), do: Process.send_after(self(), :update, 5000)

    case Cachex.get(:app_cache, "raw_mempool") do
      {:ok, mempool} ->
        {:ok,
         assign(socket,
           raw_mempool: mempool,
           zcash_network: network,
           standalone: standalone
         )}

      _ ->
        {:ok,
         assign(socket,
           raw_mempool: [],
           zcash_network: network,
           standalone: standalone
         )}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 5000)
    {:ok, mempool} = Cachex.get(:app_cache, "raw_mempool")
    {:noreply, assign(socket, :raw_mempool, mempool)}
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
        <title>Mempool - Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">
        <%= if @standalone do %>
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
        <% end %>

        <div class="w-full">
          <div class="shadow overflow-hidden border-gray-200 rounded-lg overflow-x-auto">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3">Tx ID</th>
                  <th scope="col" class="px-4 py-3">Block</th>
                  <th scope="col" class="px-4 py-3">Time</th>
                  <th scope="col" class="px-4 py-3">Fee (ZEC)</th>
                  <th scope="col" class="px-4 py-3">Size</th>
                  <th scope="col" class="px-4 py-3">TX Type</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200 dark:bg-gray-800 dark:divide-gray-700">
                <%= for tx <- @raw_mempool do %>
                  <tr class="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-indigo-600 hover:text-indigo-500 dark:text-white">
                      <a href={"/transactions/#{tx["txid"]}"}><%= tx["txid"] %></a>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= tx["info"]["height"] %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= mined_time_rel(tx["info"]["time"]) %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= format_mempool_fee(tx["info"]["fee"]) %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= tx["info"]["size"] %>
                    </td>
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

  # ── Helpers ─────────────────────────────────────────────────────────────────────

  defp mined_time_rel(unix_timestamp) when is_integer(unix_timestamp) do
    Timex.from_unix(unix_timestamp) |> Timex.format!("{relative}", :relative)
  end

  defp mined_time_rel(_), do: "—"

  # This is the correct formatter for mempool fees (already in ZEC)
  defp format_mempool_fee(amount) when is_number(amount) do
    amount
    |> Decimal.from_float()
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end

  defp format_mempool_fee(_), do: "0.00000000"
end
