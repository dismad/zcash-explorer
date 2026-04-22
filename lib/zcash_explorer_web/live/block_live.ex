defmodule ZcashExplorerWeb.BlockLive do
  use Phoenix.LiveView, layout: false
  import ZcashExplorerWeb.TransactionHelper

  @impl true
  def mount(%{"hash" => hash}, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    case Zcashex.getblock(hash, 2) do
      {:ok, block_map} ->
        block = Zcashex.Block.from_map(block_map)

        # 1. Fetch full transactions in this block
        block_txs =
          if block && block.tx do
            block.tx
            |> Enum.reduce(%{}, fn tx, acc ->
              case Zcashex.getrawtransaction(tx.txid, 1) do
                {:ok, full_map} -> Map.put(acc, tx.txid, full_map)
                _ -> acc
              end
            end)
          else
            %{}
          end

        # 2. Collect all previous txids referenced by vins
        prev_txids = collect_prev_txids(block_txs)

        # 3. Fetch missing previous transactions
        prev_txs =
          prev_txids
          |> Enum.reduce(%{}, fn txid, acc ->
            case Zcashex.getrawtransaction(txid, 1) do
              {:ok, full_map} -> Map.put(acc, txid, full_map)
              _ -> acc
            end
          end)

        full_cache = Map.merge(block_txs, prev_txs)

        {:ok,
         assign(socket,
           block: block,
           hash: hash,
           zcash_network: network,
           standalone: standalone,
           full_cache: full_cache
         )}

      _ ->
        {:ok,
         assign(socket,
           block: nil,
           hash: hash,
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
        <title>Block <%= @hash %> - Zcash Explorer</title>
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

        <div class="mx-auto px-4 py-8">
          <h1 class="text-2xl font-semibold mb-6">Details for the Zcash block #<%= @block && @block.height %></h1>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Left column - Main info -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <dl class="grid grid-cols-2 gap-x-8 gap-y-6 text-sm">
                <div>
                  <dt class="text-gray-500">Hash</dt>
                  <dd class="font-mono break-all mt-1"><%= @block && @block.hash %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Mined on</dt>
                  <dd class="mt-1"><%= @block && @block.time %> (<%= relative_time(@block && @block.time) %>)</dd>
                </div>
                <div>
                  <dt class="text-gray-500">Height</dt>
                  <dd class="font-semibold mt-1"><%= @block && @block.height %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Miner</dt>
                  <dd class="font-mono mt-1"><%= miner_address(@block) %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Input count</dt>
                  <dd class="mt-1"><%= input_count(@block) %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Output count</dt>
                  <dd class="mt-1"><%= output_count(@block) %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Input total</dt>
                  <dd class="mt-1"><%= format_zec(input_total(@block)) %> ZEC</dd>
                </div>
                <div>
                  <dt class="text-gray-500">Output total</dt>
                  <dd class="mt-1"><%= format_zec(output_total(@block)) %> ZEC</dd>
                </div>
                <div>
                  <dt class="text-gray-500">Total Fees</dt>
                  <dd class="mt-1 font-medium"><%= format_zec(total_fees(@block, @full_cache)) %> ZEC</dd>
                </div>
              </dl>
            </div>

            <!-- Right column - Technical Details -->
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <h3 class="font-semibold mb-4">Technical Details</h3>
              <dl class="space-y-4 text-sm">
                <div class="flex justify-between"><dt class="text-gray-500">Difficulty</dt><dd><%= @block && @block.difficulty %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Size</dt><dd><%= @block && @block.size %> bytes</dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Version</dt><dd><%= @block && @block.version %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Confirmations</dt><dd><%= @block && @block.confirmations %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Bits</dt><dd class="font-mono"><%= @block && @block.bits %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Merkle root</dt><dd class="font-mono break-all"><%= @block && @block.merkleroot %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Chainwork</dt><dd class="font-mono"><%= @block && @block.chainwork %></dd></div>
                <div class="flex justify-between"><dt class="text-gray-500">Nonce</dt><dd class="font-mono"><%= @block && @block.nonce %></dd></div>
              </dl>
            </div>
          </div>

          <!-- Transactions table -->
          <h2 class="text-lg font-semibold mt-10 mb-4">Transactions included in this block</h2>
          <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
            <table class="w-full text-sm">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left">BLOCK#</th>
                  <th class="px-6 py-3 text-left">HASH</th>
                  <th class="px-6 py-3 text-right">INPUTS</th>
                  <th class="px-6 py-3 text-right">OUTPUTS</th>
                  <th class="px-6 py-3 text-right">OUTPUT (ZEC)</th>
                  <th class="px-6 py-3 text-right">FEE (ZEC)</th>
                  <th class="px-6 py-3 text-left">TX TYPE</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for tx <- @block && @block.tx || [] do %>
                  <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                    <td class="px-6 py-4 font-medium"><%= @block && @block.height %></td>
                    <td class="px-6 py-4 font-mono text-indigo-600 hover:text-indigo-500">
                      <a href={tx_link(tx)}><%= tx.txid %></a>
                    </td>
                    <td class="px-6 py-4 text-right"><%= length(tx.vin || []) %></td>
                    <td class="px-6 py-4 text-right"><%= length(tx.vout || []) %></td>
                    <td class="px-6 py-4 text-right font-medium"><%= format_zec(tx_output_total(tx)) %></td>
                    <td class="px-6 py-4 text-right font-medium"><%= format_zec(tx_fee(tx, @full_cache)) %></td>
                    <td class="px-6 py-4">
                      <%= tx_type(tx) %>
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

  # All your original helpers stay exactly the same
  defp tx_link(tx), do: "/transactions/#{tx.txid}"

  defp miner_address(nil), do: "Unknown"

  defp miner_address(block) do
    coinbase = Enum.find(block.tx || [], &(&1.vin && length(&1.vin) > 0 && hd(&1.vin).coinbase))

    case coinbase && coinbase.vout && List.first(coinbase.vout) do
      %{scriptPubKey: %{addresses: [addr | _]}} -> addr
      _ -> "Unknown"
    end
  end

  defp input_count(nil), do: 0

  defp input_count(block),
    do: Enum.reduce(block.tx || [], 0, fn tx, acc -> acc + length(tx.vin || []) end)

  defp output_count(nil), do: 0

  defp output_count(block),
    do: Enum.reduce(block.tx || [], 0, fn tx, acc -> acc + length(tx.vout || []) end)

  defp input_total(_), do: 0.0

  defp output_total(nil), do: 0.0

  defp output_total(block) do
    Enum.reduce(block.tx || [], Decimal.new(0), fn tx, acc ->
      Decimal.add(acc, Decimal.from_float(tx.valueBalance || 0.0))
    end)
    |> Decimal.to_float()
  end

  defp tx_output_total(nil), do: 0.0

  defp tx_output_total(tx) do
    Enum.reduce(tx.vout || [], 0.0, fn vout, acc ->
      acc + (vout.value || 0.0)
    end)
  end

  defp tx_fee(nil, _full_cache), do: 0.0

  defp tx_fee(tx, full_cache) do
    full = Map.get(full_cache, tx.txid)

    if is_nil(full) || is_coinbase?(full) do
      0.0
    else
      vin_sum = calculate_vin_sum(full, full_cache)
      vout_sum = calculate_vout_sum(full)
      vpub_old = calculate_vpub_old(full)
      vpub_new = calculate_vpub_new(full)
      sapling = full["valueBalanceZat"] || 0
      orchard = get_in(full, ["orchard", "valueBalanceZat"]) || 0
      fee_zats = vin_sum - vout_sum - vpub_old + vpub_new + sapling + orchard
      fee_zats / 100_000_000.0
    end
  end

  defp total_fees(nil, _full_cache), do: 0.0

  defp total_fees(block, full_cache) do
    Enum.reduce(block.tx || [], 0.0, fn tx, acc ->
      acc + tx_fee(tx, full_cache)
    end)
  end

  defp collect_prev_txids(block_txs) do
    block_txs
    |> Map.values()
    |> Enum.flat_map(fn full ->
      (full["vin"] || [])
      |> Enum.filter(& &1["txid"])
      |> Enum.map(& &1["txid"])
    end)
    |> Enum.uniq()
  end

  defp calculate_vin_sum(full_tx, full_cache) do
    Enum.reduce(full_tx["vin"] || [], 0, fn vin, acc ->
      case {vin["txid"], vin["vout"]} do
        {ptxid, idx} when is_binary(ptxid) and is_integer(idx) ->
          prev_tx = Map.get(full_cache, ptxid) || %{}
          vout = Enum.at(prev_tx["vout"] || [], idx)
          acc + safe_zats(vout)

        _ ->
          acc
      end
    end)
  end

  defp calculate_vout_sum(full_tx) do
    Enum.reduce(full_tx["vout"] || [], 0, fn vout, acc ->
      acc + safe_zats(vout)
    end)
  end

  defp calculate_vpub_old(full_tx) do
    Enum.reduce(full_tx["vjoinsplit"] || [], 0, fn j, acc ->
      acc + (j["vpub_oldZat"] || 0)
    end)
  end

  defp calculate_vpub_new(full_tx) do
    Enum.reduce(full_tx["vjoinsplit"] || [], 0, fn j, acc ->
      acc + (j["vpub_newZat"] || 0)
    end)
  end

  defp safe_zats(nil), do: 0

  defp safe_zats(vout) when is_map(vout) do
    vout["valueZat"] || (vout["value"] && round(vout["value"] * 100_000_000)) || 0
  end

  defp safe_zats(_), do: 0

  defp is_coinbase?(full_tx) do
    vin = full_tx["vin"]
    vin && length(vin) > 0 && Map.get(hd(vin), "coinbase") != nil
  end

  defp format_zec(amount) when is_number(amount) do
    amount
    |> Decimal.from_float()
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end

  defp format_zec(_), do: "0.00000000"

  defp relative_time(nil), do: ""

  defp relative_time(unix_time) when is_integer(unix_time) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    diff = now - unix_time

    cond do
      diff < 60 -> "#{diff} seconds ago"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      true -> "#{div(diff, 3600)} hours ago"
    end
  end
end
