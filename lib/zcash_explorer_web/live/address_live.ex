defmodule ZcashExplorerWeb.AddressLive do
  use Phoenix.LiveView, layout: false

  def mount(%{"address" => address} = params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    {:ok, info} = Cachex.get(:app_cache, "metrics")
    latest_block = info["blocks"]

    default_range = 1152
    e = params["e"] |> parse_int(latest_block)
    s = params["s"] |> parse_int(latest_block - default_range)
    capped_e = min(e, latest_block)

    {:ok, balance} = Zcashex.getaddressbalance(address)
    {:ok, txids} = Zcashex.getaddresstxids(address, s, capped_e)

    txs = enrich_transactions(txids, address)
    qr = generate_qr(address)

    total_received = Enum.reduce(txs, 0, fn tx, acc -> acc + tx["incoming"] end)
    total_spent    = Enum.reduce(txs, 0, fn tx, acc -> acc + tx["outgoing"] end)

    {:ok,
     assign(socket,
       address: address,
       balance: balance,
       txs: txs,
       qr: qr,
       total_received: total_received,
       total_spent: total_spent,
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

        <div class="mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">

            <!-- Left Column - Details -->
            <div class="lg:col-span-4">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6 sticky top-8">
                <div class="text-sm text-gray-500 mb-2">Details for the Zcash address:</div>
                <div class="font-mono text-sm break-all mb-8"><%= @address %></div>

                <div class="flex justify-center mb-10">
                  <img src={"data:image/png;base64,#{@qr}"} class="w-56 h-56 border border-gray-200 dark:border-gray-700 rounded-3xl" alt="QR Code" />
                </div>

                <div class="space-y-6 text-sm">
                  <div class="flex justify-between items-baseline border-b pb-3">
                    <div class="text-gray-600">Balance</div>
                    <div class="font-semibold text-emerald-600 text-2xl"><%= format_zec(@balance["balance"] || 0) %> ZEC</div>
                  </div>

                  <div class="flex justify-between items-baseline border-b pb-3">
                    <div class="text-gray-600">Received</div>
                    <div class="font-medium"><%= format_zec(@total_received) %> ZEC</div>
                  </div>

                  <div class="flex justify-between items-baseline">
                    <div class="text-gray-600">Spent</div>
                    <div class="font-medium"><%= format_zec(@total_spent) %> ZEC</div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Column - Transactions -->
            <div class="lg:col-span-8">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6">
                <h2 class="text-xl font-semibold mb-6">
                  Transactions from block #<%= @start_block %> to #<%= @end_block %>
                </h2>

                <div class="space-y-4">
                  <%= for tx <- @txs do %>
                    <div class="border border-gray-200 dark:border-gray-700 rounded-2xl p-5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                      <!-- Block + Txid (block is now clickable) -->
                      <div class="text-xs text-gray-500 mb-3">
                        block: 
                        <a href={"/blocks/#{tx["height"]}"} class="hover:text-indigo-600">
                          <%= tx["height"] || "—" %>
                        </a>
                        <span class="text-gray-300 mx-2">|</span> 
                        txid: 
                        <a href={"/transactions/#{tx["txid"]}"} class="font-mono hover:text-indigo-600 break-all">
                          <%= tx["txid"] %>
                        </a>
                      </div>

                      <!-- Received and Spent -->
                      <div class="grid grid-cols-2 gap-8 text-sm">
                        <div>
                          <div class="text-emerald-600 font-medium text-xs mb-0.5">Received</div>
                          <div class="text-base font-semibold">
                            <%= if tx["incoming"] > 0 do %>
                              +<%= format_zec(tx["incoming"]) %> ZEC
                            <% else %>
                              0 ZEC
                            <% end %>
                          </div>
                        </div>

                        <div class="text-right">
                          <div class="text-red-600 font-medium text-xs mb-0.5">Spent</div>
                          <div class="text-base font-semibold">
                            <%= if tx["outgoing"] > 0 do %>
                              -<%= format_zec(tx["outgoing"]) %> ZEC
                            <% else %>
                              0 ZEC
                            <% end %>
                          </div>
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

  defp format_zec(zat) when is_integer(zat) do
    Float.round(zat / 100_000_000, 8)
  end
  defp format_zec(zat) when is_number(zat) do
    Float.round(zat, 8)
  end
  defp format_zec(_), do: 0.0

  defp enrich_transactions(txids, address) do
    txids
    |> Enum.map(fn txid ->
      {:ok, tx} = Zcashex.getrawtransaction(txid, 1)
      incoming = sum_matching_vout(tx, address)
      outgoing = sum_matching_vin(tx, address)
      tx
      |> Map.put("txid", txid)
      |> Map.put("incoming", incoming)
      |> Map.put("outgoing", outgoing)
      |> Map.put("height", tx["height"])
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