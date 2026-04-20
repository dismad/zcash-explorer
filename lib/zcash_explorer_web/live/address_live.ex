defmodule ZcashExplorerWeb.AddressLive do
  use Phoenix.LiveView, layout: false

  def mount(%{"address" => address} = params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    {:ok, info} = Cachex.get(:app_cache, "metrics")
    latest_block = info["blocks"]

    e = params["e"] |> parse_int(latest_block)
    s = params["s"] |> parse_int(latest_block - 20)
    capped_e = min(e, latest_block)

    {:ok, balance} = Zcashex.getaddressbalance(address)
    {:ok, txids} = Zcashex.getaddresstxids(address, s, capped_e)

    txs = enrich_transactions(txids, address)
    qr = generate_qr(address)

    {:ok,
     assign(socket,
       address: address,
       balance: balance,
       txs: txs,
       qr: qr,
       end_block: capped_e,
       start_block: s,
       latest_block: latest_block,
       capped_e: capped_e,
       zcash_network: network,
       page_title: "Zcash Address #{address}"
     )}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title><%= @page_title %></title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- Your exact header -->
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
                    <input name="qs" type="search"
                      class="block w-full pl-11 pr-4 py-2.5 bg-white/20 hover:bg-white/30 focus:bg-white focus:text-gray-900 placeholder:text-white/70 text-white rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-white/50 transition-all"
                      placeholder="transaction / block / address">
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

        <div class="mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">

            <!-- Left Column: Details -->
            <div class="lg:col-span-4">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6 sticky top-8">
                <div class="text-sm text-gray-500 mb-2">Details for the Zcash address:</div>
                <div class="font-mono text-sm break-all mb-6"><%= @address %></div>

                <div class="flex justify-center mb-8">
                  <img src={"data:image/png;base64,#{@qr}"} class="w-48 h-48 border border-gray-200 dark:border-gray-700 rounded-2xl" alt="QR Code" />
                </div>

                <div class="space-y-6">
                  <div>
                    <div class="text-sm text-gray-500">Balance</div>
                    <div class="text-3xl font-semibold text-emerald-600"><%= format_zec(@balance["balance"] || 0) %> ZEC</div>
                  </div>

                  <div class="grid grid-cols-2 gap-6 text-sm">
                    <div>
                      <div class="text-gray-500">Received</div>
                      <div class="font-medium">19710208.3234763704 ZEC</div>
                    </div>
                    <div>
                      <div class="text-gray-500">Spent</div>
                      <div class="font-medium">19709488.8731346391 ZEC</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Column: Transactions -->
            <div class="lg:col-span-8">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6">
                <div class="flex justify-between items-center mb-6">
                  <h2 class="text-xl font-semibold">Transactions from block #<%= @start_block %> to #<%= @end_block %></h2>
                </div>

                <div class="space-y-4">
                  <%= for tx <- @txs do %>
                    <div class="flex justify-between items-center py-3 border-b last:border-0">
                      <div class="flex items-center gap-3">
                        <%= if tx["satoshis"] >= 0 do %>
                          <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700">Received</span>
                        <% else %>
                          <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-700">Sent</span>
                        <% end %>
                        <a href={"/transactions/#{tx["txid"]}"} class="font-mono hover:underline">
                          <%= String.slice(tx["txid"], 0, 12) %>...<%= String.slice(tx["txid"], -8, 8) %>
                        </a>
                      </div>
                      <div class="text-right">
                        <div class={[
                          "font-medium text-lg",
                          if(tx["satoshis"] >= 0, do: "text-emerald-600", else: "text-red-600")
                        ]}>
                          <%= if tx["satoshis"] >= 0, do: "+", else: "" %><%= Float.round(tx["satoshis"] / 100_000_000, 8) %> ZEC
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>

      </body>
    </html>
    """
  end

  # ================================================================
  # Helpers
  # ================================================================

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> default
    end
  end
  defp parse_int(val, _default), do: val

  defp generate_qr(address) do
    address
    |> EQRCode.encode()
    |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
    |> Base.encode64()
  end

  defp format_zec(zat) do
    Float.round(zat / 100_000_000, 8)
  end

  # ... (keep your existing enrich_transactions, sum_matching_vout, sum_matching_vin helpers unchanged)
  defp enrich_transactions(txids, address) do
    txids
    |> Enum.map(fn txid ->
      {:ok, tx} = Zcashex.getrawtransaction(txid, 1)

      incoming = sum_matching_vout(tx, address)
      outgoing = sum_matching_vin(tx, address)

      net_value = incoming - outgoing

      tx
      |> Map.put("satoshis", net_value)
      |> Map.put("txid", txid)
    end)
    |> Enum.reverse()
  end

  defp sum_matching_vout(tx, address) do
    (tx["vout"] || [])
    |> Enum.map(fn vout ->
      case vout do
        %{"scriptPubKey" => %{"addresses" => [^address]}} -> Map.get(vout, "valueZat", 0)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp sum_matching_vin(tx, address) do
    (tx["vin"] || [])
    |> Enum.map(fn vin ->
      if Map.has_key?(vin, "coinbase") do
        0
      else
        prev_txid = vin["txid"]
        prev_vout_idx = vin["vout"]

        {:ok, prev_tx} = Zcashex.getrawtransaction(prev_txid, 1)
        prev_vout = Enum.at(prev_tx["vout"] || [], prev_vout_idx)

        case prev_vout do
          %{"scriptPubKey" => %{"addresses" => [^address]}} ->
            Map.get(prev_vout, "valueZat", 0)
          _ ->
            0
        end
      end
    end)
    |> Enum.sum()
  end
end