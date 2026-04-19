defmodule ZcashExplorerWeb.TransactionLive do
  use Phoenix.LiveView, layout: false
  import ZcashExplorerWeb.TransactionHelper

  @impl true
  def mount(%{"txid" => txid}, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx_map} ->
        tx = Zcashex.Transaction.from_map(tx_map)
        {:ok, assign(socket,
          tx: tx,
          txid: txid,
          zcash_network: network,
          standalone: standalone
        )}
      _ ->
        {:ok, assign(socket,
          tx: nil,
          txid: txid,
          zcash_network: network,
          standalone: standalone
        )}
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
        <%= if @standalone do %>
          <header>
            <nav x-data="{ open: false }" class="shrink-0 bg-indigo-600 dark:bg-gray-800">
              <div class="max-w-7xl mx-auto px-2 sm:px-4 lg:px-8">
                <div class="relative flex items-center justify-between h-16">
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
            </nav>
          </header>
        <% end %>

        <div class="mx-auto px-4 py-8">
          <h1 class="text-2xl font-semibold mb-6">Details for the Zcash Transaction ID <%= @txid %></h1>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between"><dt class="text-gray-500">Confirmations</dt><dd class="font-semibold"><%= @tx && @tx.confirmations || 0 %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Block Id</dt><dd class="font-medium"><%= @tx && @tx.height %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">JoinSplits ?</dt><dd><%= if length(@tx && @tx.vjoinsplit || []) > 0, do: "Yes", else: "No" %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Size (bytes)</dt><dd><%= @tx && @tx.size %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Transaction fee</dt><dd><%= format_zec(tx_fee(@tx)) %> ZEC</dd></div>
              </dl>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between"><dt class="text-gray-500">Public Inputs / Outputs</dt><dd><%= length(@tx && @tx.vin || []) %> / <%= length(@tx && @tx.vout || []) %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Transferred from shielded pool</dt><dd>0.0 ZEC</dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Version</dt><dd><%= @tx && @tx.version %></dd></div>
              </dl>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between"><dt class="text-gray-500">Shielded Inputs / Outputs</dt><dd><%= length(@tx && @tx.vShieldedSpend || []) %> / <%= length(@tx && @tx.vShieldedOutput || []) %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Orchard Action transfers</dt><dd><%= length(@tx && @tx.orchard && @tx.orchard.actions || []) %></dd></div>
              </dl>
            </div>
          </div>

          <!-- Tx Type -->
          <div class="mt-6 flex items-center gap-x-3">
            <span class="text-gray-500">Tx Type</span>
            <%= case tx_type(@tx) do %>
              <% "coinbase" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-yellow-400 text-gray-900 capitalize">💰 Coinbase</span>
              <% "shielded" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-200 text-gray-900 capitalize">🛡 Shielded</span>
              <% "sapling" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-emerald-200 text-gray-900 capitalize">🛡️ Sapling</span>
              <% "sprout" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-amber-200 text-gray-900 capitalize">🌱 Sprout</span>
              <% "transparent" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-200 text-gray-900 capitalize">🔍 Public</span>
              <% "shielding" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-50 text-gray-900 capitalize">Shielding ( T-Z )</span>
              <% "deshielding" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-50 text-gray-900 capitalize">Deshielding ( Z-T )</span>
              <% "mixed" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-200 text-gray-900 capitalize">Mixed</span>
              <% "orchard" -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-200 text-gray-900 capitalize">🌳 Orchard</span>
              <% _ -> %> <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-200 text-gray-900">Unknown</span>
            <% end %>
          </div>

          <!-- Public Transfers -->
          <div class="mt-8">
            <h2 class="text-lg font-semibold mb-4">Public Transfers</h2>
            <div class="flex items-center gap-8 bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <div class="flex-1">
                <div class="text-sm text-gray-500 mb-2">Inputs (<%= length(@tx && @tx.vin || []) %>)</div>
                <%= if length(@tx && @tx.vShieldedSpend || []) > 0 do %>
                  <div class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-100 text-emerald-700 rounded-full text-sm font-medium">
                    <span class="text-lg">🛡️</span> Shielded
                  </div>
                <% else %>
                  <div class="text-gray-400">No public inputs</div>
                <% end %>
              </div>

              <div class="text-4xl text-gray-300">→</div>

              <div class="flex-1">
                <div class="text-sm text-gray-500 mb-2">Outputs (<%= length(@tx && @tx.vout || []) %>)</div>
                <%= for vout <- @tx && @tx.vout || [] do %>
                  <div class="flex justify-between items-center py-2 border-b last:border-none">
                    <%= if addr = first_address(vout) do %>
                      <a href={address_link(addr)} class="font-mono text-sm text-indigo-600 hover:underline">
                        <%= addr %>
                      </a>
                    <% else %>
                      <span class="font-mono text-sm text-gray-400">No address</span>
                    <% end %>
                    <span class="font-medium"><%= format_zec(vout.value) %> ZEC</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  # === Accurate fee (exact match to block_live.ex and your Rust tool) ===
  defp tx_fee(nil), do: 0.0
  defp tx_fee(tx) do
    if is_coinbase?(tx) do
      0.0
    else
      vin_sum = calculate_vin_sum(tx)
      vout_sum = calculate_vout_sum(tx)
      vpub_old = calculate_vpub_old(tx)
      vpub_new = calculate_vpub_new(tx)
      sapling = tx.valueBalanceZat || 0
      orchard = tx.orchard && tx.orchard.valueBalanceZat || 0

      fee_zats = vin_sum - vout_sum - vpub_old + vpub_new + sapling + orchard
      fee_zats / 100_000_000.0
    end
  end

  defp is_coinbase?(tx) do
    tx.vin && length(tx.vin) > 0 && hd(tx.vin).coinbase != nil
  end

  defp calculate_vin_sum(tx) do
    Enum.reduce(tx.vin || [], 0, fn vin, acc ->
      acc + (vin.valueZat || vin.valueSat || 0)
    end)
  end

  defp calculate_vout_sum(tx) do
    Enum.reduce(tx.vout || [], 0, fn vout, acc ->
      acc + (vout.valueZat || vout.value || 0)
    end)
  end

  defp calculate_vpub_old(tx) do
    Enum.reduce(tx.vjoinsplit || [], 0, fn j, acc ->
      acc + (j.vpub_oldZat || 0)
    end)
  end

  defp calculate_vpub_new(tx) do
    Enum.reduce(tx.vjoinsplit || [], 0, fn j, acc ->
      acc + (j.vpub_newZat || 0)
    end)
  end

  # Your existing helpers (unchanged)
  defp first_address(vout) do
    case vout && vout.scriptPubKey && vout.scriptPubKey.addresses do
      addresses when is_list(addresses) and length(addresses) > 0 -> hd(addresses)
      _ -> nil
    end
  end

  defp address_link(nil), do: "#"
  defp address_link(addr), do: "/addresses/#{addr}"

  defp format_zec(amount) when is_number(amount) do
    amount
    |> Decimal.from_float()
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end
  defp format_zec(_), do: "0.00000000"
end