defmodule ZcashExplorerWeb.TransactionLive do
  use Phoenix.LiveView, layout: false
  import Phoenix.HTML
  import Phoenix.HTML.Tag
  import ZcashExplorerWeb.TransactionHelper

  @impl true
  def mount(%{"txid" => txid}, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx_map} ->
        tx = Zcashex.Transaction.from_map(tx_map)
        full_cache = fetch_prev_txs(tx)

        {:ok, assign(socket,
          tx: tx,
          txid: txid,
          zcash_network: network,
          standalone: standalone,
          full_cache: full_cache
        )}

      _ ->
        {:ok, assign(socket,
          tx: nil,
          txid: txid,
          zcash_network: network,
          standalone: standalone,
          full_cache: %{}
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
                    <input name="qs" type="search" class="block w-full pl-11 pr-4 py-2.5 bg-white/20 hover:bg-white/30 focus:bg-white focus:text-gray-900 placeholder:text-white/70 text-white rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-white/50 transition-all" placeholder="transaction / block / address">
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

        <div class="mx-auto px-4 py-8">
          <h1 class="text-2xl font-semibold mb-6">Transaction <%= @txid %></h1>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <!-- Stats -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between"><dt class="text-gray-500">Confirmations</dt><dd class="font-semibold"><%= @tx && @tx.confirmations || 0 %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Block Height</dt><dd><%= @tx && @tx.height %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Size</dt><dd><%= @tx && @tx.size %> bytes</dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Fee</dt><dd class="font-medium"><%= format_zec(tx_fee(@tx, @full_cache)) %> ZEC</dd></div>
              </dl>
            </div>

            <!-- More stats -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between"><dt class="text-gray-500">Public Inputs / Outputs</dt><dd><%= length(@tx && @tx.vin || []) %> / <%= length(@tx && @tx.vout || []) %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Shielded Inputs / Outputs</dt><dd><%= length(@tx && @tx.vShieldedSpend || []) %> / <%= length(@tx && @tx.vShieldedOutput || []) %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Orchard Actions</dt><dd><%= length(@tx && @tx.orchard && @tx.orchard.actions || []) %></dd></div>
              </dl>
            </div>

            <!-- TX Type -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6 flex items-center gap-3">
              <span class="text-gray-500">Type</span>
              <%= tx_type(@tx) %>
            </div>
          </div>

          <!-- Public Transfers -->
          <%= public_transfers_section(assigns) %>
        </div>
      </body>
    </html>
    """
  end

  defp public_transfers_section(assigns) do
    content_tag(:div, class: "mt-8 bg-white dark:bg-gray-800 shadow rounded-lg p-6") do
      [
        content_tag(:h2, "Public Transfers", class: "text-lg font-semibold mb-4"),

        content_tag(:div, class: "flex items-center gap-8") do
          [
            # INPUTS - now shows correct address + real previous output amount
            content_tag(:div, class: "flex-1") do
              [
                content_tag(:div, "Inputs (#{length(assigns.tx && assigns.tx.vin || [])})", class: "text-sm text-gray-500 mb-3"),
                content_tag(:div, class: "space-y-2") do
                  for vin <- assigns.tx && assigns.tx.vin || [] do
                    address = get_input_address(vin, assigns.full_cache) || "—"
                    amount  = get_input_value(vin, assigns.full_cache)
                    content_tag(:div, class: "flex justify-between py-2 border-b last:border-0 bg-gray-50 dark:bg-gray-700 p-4 rounded border") do
                      [
                        content_tag(:a, address, href: "/addresses/#{address}", class: "font-mono text-sm text-indigo-600 hover:underline break-all"),
                        content_tag(:span, "#{format_zec(amount)} ZEC", class: "font-medium")
                      ]
                    end
                  end
                end
              ]
            end,

            content_tag(:div, "→", class: "text-4xl text-gray-300"),

            # OUTPUTS
            content_tag(:div, class: "flex-1") do
              [
                content_tag(:div, "Outputs (#{length(assigns.tx && assigns.tx.vout || [])})", class: "text-sm text-gray-500 mb-3"),
                content_tag(:div, class: "space-y-2") do
                  for vout <- assigns.tx && assigns.tx.vout || [] do
                    address = first_address(vout)
                    content_tag(:div, class: "flex justify-between items-center py-2 border-b last:border-none bg-gray-50 dark:bg-gray-700 p-4 rounded border") do
                      [
                        if address do
                          content_tag(:a, address, href: "/addresses/#{address}", class: "font-mono text-sm text-indigo-600 hover:underline break-all")
                        else
                          content_tag(:span, "No address", class: "font-mono text-sm text-gray-400")
                        end,
                        content_tag(:span, "#{format_zec(vout.value || 0)} ZEC", class: "font-medium")
                      ]
                    end
                  end
                end
              ]
            end
          ]
        end
      ]
    end
  end

  # ── NEW HELPER: resolves real input address from previous output ──
  defp get_input_address(vin, full_cache) do
    cond do
      vin.address != nil -> vin.address
      vin.txid && vin.vout != nil ->
        prev_tx = Map.get(full_cache, vin.txid)
        if prev_tx && prev_tx.vout && Enum.at(prev_tx.vout, vin.vout) do
          out = Enum.at(prev_tx.vout, vin.vout)
          List.first(out.scriptPubKey.addresses || [])
        else
          nil
        end
      true -> nil
    end
  end

  # ==================================================================
  # Your original helpers (100% unchanged)
  # ==================================================================
  defp tx_fee(nil, _), do: 0.0
  defp tx_fee(tx, full_cache) do
    if is_coinbase?(tx) do
      0.0
    else
      vin_sum = calculate_vin_sum(tx, full_cache)
      vout_sum = calculate_vout_sum(tx)
      vpub_old = calculate_vpub_old(tx)
      vpub_new = calculate_vpub_new(tx)
      sapling = tx.valueBalanceZat || 0
      orchard = tx.orchard && tx.orchard.valueBalanceZat || 0
      fee_zats = vin_sum - vout_sum - vpub_old + vpub_new + sapling + orchard
      fee_zats / 100_000_000.0
    end
  end

  defp is_coinbase?(tx), do: tx.vin && length(tx.vin) > 0 && hd(tx.vin).coinbase != nil

  defp calculate_vin_sum(tx, full_cache) do
    Enum.reduce(tx.vin || [], 0, fn vin, acc ->
      acc + get_input_value(vin, full_cache)
    end)
  end

  defp get_input_value(vin, full_cache) do
    cond do
      Map.get(vin, :valueZat) != nil -> Map.get(vin, :valueZat)
      Map.get(vin, :valueSat) != nil -> Map.get(vin, :valueSat)
      Map.get(vin, :value) != nil -> round(Map.get(vin, :value) * 100_000_000)
      vin.txid && vin.vout != nil ->
        prev_tx = Map.get(full_cache, vin.txid)
        if prev_tx && prev_tx.vout && Enum.at(prev_tx.vout, vin.vout) do
          out = Enum.at(prev_tx.vout, vin.vout)
          Map.get(out, :valueZat) || Map.get(out, :valueSat) || round((Map.get(out, :value) || 0) * 100_000_000)
        else
          0
        end
      true -> 0
    end
  end

  defp calculate_vout_sum(tx) do
    Enum.reduce(tx.vout || [], 0, fn vout, acc ->
      acc + safe_zats(vout)
    end)
  end

  defp calculate_vpub_old(tx) do
    Enum.reduce(tx.vjoinsplit || [], 0, fn j, acc ->
      acc + (Map.get(j, :vpub_oldZat) || 0)
    end)
  end

  defp calculate_vpub_new(tx) do
    Enum.reduce(tx.vjoinsplit || [], 0, fn j, acc ->
      acc + (Map.get(j, :vpub_newZat) || 0)
    end)
  end

  defp safe_zats(item) do
    Map.get(item, :valueZat) || Map.get(item, :valueSat) || round((Map.get(item, :value) || 0) * 100_000_000) || 0
  end

  defp fetch_prev_txs(tx) do
    txids = Enum.map(tx.vin || [], & &1.txid) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    txids
    |> Task.async_stream(&Zcashex.getrawtransaction(&1, 1), max_concurrency: 8, timeout: 10_000)
    |> Enum.reduce(%{}, fn
      {:ok, {:ok, raw}}, acc ->
        prev_tx = Zcashex.Transaction.from_map(raw)
        Map.put(acc, prev_tx.txid, prev_tx)
      _, acc -> acc
    end)
  end

  defp first_address(vout) do
    case vout && vout.scriptPubKey && vout.scriptPubKey.addresses do
      addresses when is_list(addresses) and length(addresses) > 0 -> hd(addresses)
      _ -> nil
    end
  end

  defp format_zec(nil), do: "0.00000000"
  defp format_zec(amount) when is_integer(amount) do
    amount / 100_000_000 |> Decimal.from_float() |> Decimal.round(8) |> Decimal.to_string(:normal)
  end
  defp format_zec(amount) when is_float(amount) or is_number(amount) do
    amount |> Decimal.from_float() |> Decimal.round(8) |> Decimal.to_string(:normal)
  end
  defp format_zec(_), do: "0.00000000"
end