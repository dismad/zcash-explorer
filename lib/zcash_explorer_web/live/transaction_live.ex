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
        full_cache = fetch_prev_txs(tx)

        {:ok,
         assign(socket,
           tx: tx,
           txid: txid,
           zcash_network: network,
           standalone: standalone,
           full_cache: full_cache
         )}

      _ ->
        {:ok,
         assign(socket,
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
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Transaction <%= @txid %> - Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
        <script defer phx-track-static type="text/javascript" src="/js/app.js"></script>
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">
        <%= if @standalone do %>
          <header class="bg-gradient-to-r from-blue-950 via-blue-900 to-blue-800 text-white sticky top-0 z-50 shadow-md">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div class="h-14 flex items-center justify-between">
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
        <div class="mx-auto px-4 py-8">
          <h1 class="text-base sm:text-2xl font-semibold mb-6">
            <span class="text-gray-500 font-normal">Transaction</span>
            <br class="sm:hidden" />
            <span class="font-mono text-sm sm:text-xl break-all"><%= @txid %></span>
          </h1>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <!-- Stats -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between">
                  <dt class="text-gray-500">Confirmations</dt>
                  <dd class="font-semibold"><%= @tx && @tx.confirmations || 0 %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Block Height</dt>
                  <dd><%= @tx && @tx.height %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Size</dt>
                  <dd><%= @tx && @tx.size %> bytes</dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Fee</dt>
                  <dd class="font-medium"><%= format_zec(tx_fee(@tx, @full_cache)) %> ZEC</dd>
                </div>
              </dl>
            </div>
            <!-- More stats -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="space-y-4">
                <div class="flex justify-between">
                  <dt class="text-gray-500">Public Inputs / Outputs</dt>
                  <dd><%= length(@tx && @tx.vin || []) %> / <%= length(@tx && @tx.vout || []) %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Shielded Inputs / Outputs</dt>
                  <dd>
                    <%= length(@tx && @tx.vShieldedSpend || []) %> /
                    <%= length(@tx && @tx.vShieldedOutput || []) %>
                  </dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Orchard Actions</dt>
                  <dd><%= length(@tx && @tx.orchard && @tx.orchard.actions || []) %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500">Ironwood Actions</dt>
                  <dd><%= length(@tx && @tx.ironwood && @tx.ironwood.actions || []) %></dd>
                </div>
              </dl>
            </div>
            <!-- TX Type + Pools -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <div class="flex flex-col gap-3">
                <div class="flex items-center gap-3">
                  <span class="text-gray-500 text-sm">Type</span>
                  <%= tx_type(@tx) %>
                </div>
                <div class="flex flex-wrap items-center gap-2">
                  <span class="text-gray-500 text-sm">Pools</span>
                  <%= for badge <- pool_badges(@tx) do %>
                    <%= badge %>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <%= public_transfers_section(assigns) %>
        </div>
      </body>
    </html>
    """
  end

  defp public_transfers_section(assigns) do
    ~H"""
    <div class="mt-8 bg-white dark:bg-gray-800 shadow rounded-lg p-4 sm:p-6">
      <h2 class="text-lg font-semibold mb-4">Public Transfers</h2>
      <div class="flex flex-col lg:flex-row lg:items-start gap-4 lg:gap-8">
        <!-- Inputs -->
        <div class="flex-1 min-w-0">
          <div class="text-sm text-gray-500 mb-3">
            Inputs (<%= length((@tx && @tx.vin) || []) %>)
          </div>
          <div class="space-y-2">
            <%= for vin <- (@tx && @tx.vin) || [] do %>
              <% address = get_input_address(vin, @full_cache) || "—" %>
              <% amount = get_input_value(vin, @full_cache) %>
              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-1 py-3 px-3 bg-gray-50 dark:bg-gray-700 rounded border dark:border-gray-600">
                <a
                  href={"/address/#{address}"}
                  class="font-mono text-sm text-indigo-600 hover:underline break-all"
                >
                  <%= address %>
                </a>
                <span class="font-medium text-sm whitespace-nowrap">
                  <%= format_zec(amount) %> ZEC
                </span>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Arrow (hidden on mobile, shown on desktop) -->
        <div class="hidden lg:flex items-center justify-center text-3xl text-gray-300 pt-8">
          →
        </div>
        <!-- Mobile arrow -->
        <div class="flex lg:hidden items-center justify-center text-2xl text-gray-300 py-1">
          ↓
        </div>
        <!-- Outputs -->
        <div class="flex-1 min-w-0">
          <div class="text-sm text-gray-500 mb-3">
            Outputs (<%= length((@tx && @tx.vout) || []) %>)
          </div>
          <div class="space-y-2">
            <%= for vout <- (@tx && @tx.vout) || [] do %>
              <% address = first_address(vout) %>
              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-1 py-3 px-3 bg-gray-50 dark:bg-gray-700 rounded border dark:border-gray-600">
                <%= if address do %>
                  <a
                    href={"/address/#{address}"}
                    class="font-mono text-sm text-indigo-600 hover:underline break-all"
                  >
                    <%= address %>
                  </a>
                <% else %>
                  <span class="font-mono text-sm text-gray-400">No address</span>
                <% end %>
                <span class="font-medium text-sm whitespace-nowrap">
                  <%= format_zec(vout.value || 0) %> ZEC
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Fee calculation (includes Ironwood) ──────────────────────────────────

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
      orchard = (tx.orchard && tx.orchard.valueBalanceZat) || 0
      ironwood = (tx.ironwood && tx.ironwood.valueBalanceZat) || 0

      fee_zats = vin_sum - vout_sum - vpub_old + vpub_new + sapling + orchard + ironwood
      fee_zats / 100_000_000.0
    end
  end

  defp is_coinbase?(tx),
    do: tx.vin && length(tx.vin) > 0 && hd(tx.vin).coinbase != nil

  defp calculate_vin_sum(tx, full_cache) do
    Enum.reduce(tx.vin || [], 0, fn vin, acc ->
      acc + get_input_value(vin, full_cache)
    end)
  end

  defp get_input_value(vin, full_cache) do
    cond do
      Map.get(vin, :valueZat) != nil ->
        Map.get(vin, :valueZat)

      Map.get(vin, :valueSat) != nil ->
        Map.get(vin, :valueSat)

      Map.get(vin, :value) != nil ->
        round(Map.get(vin, :value) * 100_000_000)

      vin.txid && vin.vout != nil ->
        prev_tx = Map.get(full_cache, vin.txid)

        if prev_tx && prev_tx.vout && Enum.at(prev_tx.vout, vin.vout) do
          out = Enum.at(prev_tx.vout, vin.vout)

          Map.get(out, :valueZat) || Map.get(out, :valueSat) ||
            round((Map.get(out, :value) || 0) * 100_000_000)
        else
          0
        end

      true ->
        0
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
    Map.get(item, :valueZat) || Map.get(item, :valueSat) ||
      round((Map.get(item, :value) || 0) * 100_000_000) || 0
  end

  # ── Address helpers ──────────────────────────────────────────────────────

  defp first_address(vout) do
    case vout && vout.scriptPubKey && vout.scriptPubKey.addresses do
      addresses when is_list(addresses) and length(addresses) > 0 -> hd(addresses)
      _ -> nil
    end
  end

  defp get_input_address(vin, full_cache) do
    cond do
      vin.address != nil ->
        vin.address

      vin.txid && vin.vout != nil ->
        prev_tx = Map.get(full_cache, vin.txid)

        if prev_tx && prev_tx.vout && Enum.at(prev_tx.vout, vin.vout) do
          out = Enum.at(prev_tx.vout, vin.vout)
          List.first(out.scriptPubKey.addresses || [])
        else
          nil
        end

      true ->
        nil
    end
  end

  defp fetch_prev_txs(tx) do
    txids =
      (tx.vin || [])
      |> Enum.map(& &1.txid)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    txids
    |> Task.async_stream(&Zcashex.getrawtransaction(&1, 1), max_concurrency: 8, timeout: 10_000)
    |> Enum.reduce(%{}, fn
      {:ok, {:ok, raw}}, acc ->
        prev_tx = Zcashex.Transaction.from_map(raw)
        Map.put(acc, prev_tx.txid, prev_tx)

      _, acc ->
        acc
    end)
  end

  # ── Formatting ───────────────────────────────────────────────────────────

  defp format_zec(nil), do: "0.00000000"

  defp format_zec(amount) when is_integer(amount) do
    (amount / 100_000_000)
    |> Decimal.from_float()
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end

  defp format_zec(amount) when is_float(amount) or is_number(amount) do
    amount
    |> Decimal.from_float()
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end

  defp format_zec(_), do: "0.00000000"
end