defmodule ZcashExplorerWeb.RawMempoolLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(_params, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    if connected?(socket), do: Process.send_after(self(), :update, 5000)

    case Cachex.get(:app_cache, "raw_mempool") do
      {:ok, mempool} ->
        {:ok, assign(socket,
          raw_mempool: mempool,
          zcash_network: network,
          standalone: standalone
        )}
      _ ->
        {:ok, assign(socket,
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

  # Helper: replaces ZcashExplorerWeb.BlockView.mined_time_rel/1
  defp mined_time_rel(timestamp) when is_integer(timestamp) do
    Timex.from_unix(timestamp)
    |> Timex.format!("{relative}", :relative)
  rescue
    _ -> "—"
  end

  # Helper: replaces ZcashExplorerWeb.TransactionView.format_zec/1
  defp format_zec(amount) when is_number(amount) do
    amount
    |> Decimal.new()
    |> Decimal.div(100_000_000)           # 1 ZEC = 100_000_000 zatoshis
    |> Decimal.to_string(:normal, 8)
  rescue
    _ -> "0.00000000"
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
        <title>Raw Mempool - Zcash Explorer</title>
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- Header only on standalone page -->
        <%= if @standalone do %>
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
        <% end %>

        <!-- Table -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <h1 class="text-3xl font-semibold text-gray-900 dark:text-white mb-8">Raw Mempool</h1>

          <div class="shadow overflow-hidden border-gray-200 rounded-lg overflow-x-auto">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3">Tx ID</th>
                  <th scope="col" class="px-4 py-3">Block</th>
                  <th scope="col" class="px-4 py-3">Time</th>
                  <th scope="col" class="px-4 py-3">Fee</th>
                  <th scope="col" class="px-4 py-3">Size</th>
                </tr>
              </thead>
              <tbody class="bg-white-500 divide-y divide-gray-200">
                <%= for tx <- @raw_mempool do %>
                  <tr class="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-indigo-600 hover:text-indigo-500 animate-pulse dark:text-white dark:hover:text-white">
                      <a href={"/transactions/#{tx["txid"]}"}>
                        <%= tx["txid"] %>
                      </a>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= tx["info"]["height"] %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= mined_time_rel(tx["info"]["time"]) %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= format_zec(tx["info"]["fee"]) %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <%= tx["info"]["size"] %>
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

  # Local helpers
  defp mined_time_rel(timestamp) when is_integer(timestamp) do
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
end