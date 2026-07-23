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

        prev_txids = collect_prev_txids(block_txs)

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

        <div class="mx-auto px-3 sm:px-4 py-4 sm:py-8">
          <h1 class="text-lg sm:text-2xl font-semibold mb-4 sm:mb-6">
            Details for the Zcash block #<%= @block && @block.height %>
          </h1>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-8">
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-4 sm:p-6">
              <dl class="grid grid-cols-2 gap-x-4 sm:gap-x-8 gap-y-3 sm:gap-y-6 text-sm">
                <div class="col-span-2 sm:col-span-1">
                  <dt class="text-gray-500">Hash</dt>
                  <dd class="font-mono break-all mt-1 text-xs sm:text-sm"><%= @block && @block.hash %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Mined on</dt>
                  <dd class="mt-1 text-xs sm:text-sm">
                    <%= @block && @block.time %>
                    <span class="text-gray-400">(<%= relative_time(@block && @block.time) %>)</span>
                  </dd>
                </div>
                <div>
                  <dt class="text-gray-500">Height</dt>
                  <dd class="font-semibold mt-1"><%= @block && @block.height %></dd>
                </div>
               <div class="col-span-2 sm:col-span-1">
		  <dt class="text-gray-500">Miner</dt>
		  <dd class="mt-1 space-y-0.5">
		    <%= if name = miner_name(@block) do %>
		      <div class="font-semibold text-sm text-gray-900 dark:text-gray-100">
			<%= name %>
		      </div>
		    <% end %>
		    <div class="font-mono break-all text-xs sm:text-sm text-gray-600 dark:text-gray-300">
		      <%= miner_address(@block) %>
		    </div>
		  </dd>
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
                  <dd class="mt-1 text-xs sm:text-sm"><%= format_zec(input_total(@block, @full_cache)) %> ZEC</dd>
                </div>
                <div>
                  <dt class="text-gray-500">Output total</dt>
                  <dd class="mt-1 text-xs sm:text-sm"><%= format_zec(output_total(@block)) %> ZEC</dd>
                </div>
                <div>
                  <dt class="text-gray-500">Total Fees</dt>
                  <dd class="mt-1 font-medium"><%= format_zec(total_fees(@block, @full_cache)) %> ZEC</dd>
                </div>
              </dl>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-4 sm:p-6">
              <h3 class="font-semibold mb-3 sm:mb-4">Technical Details</h3>
              <dl class="space-y-2.5 sm:space-y-4 text-sm">
                <div class="flex justify-between gap-2">
                  <dt class="text-gray-500 shrink-0">Difficulty</dt>
                  <dd class="text-right"><%= @block && @block.difficulty %></dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="text-gray-500 shrink-0">Size</dt>
                  <dd><%= @block && @block.size %> bytes</dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="text-gray-500 shrink-0">Version</dt>
                  <dd><%= @block && @block.version %></dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="text-gray-500 shrink-0">Confirmations</dt>
                  <dd><%= @block && @block.confirmations %></dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="text-gray-500 shrink-0">Bits</dt>
                  <dd class="font-mono"><%= @block && @block.bits %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Merkle root</dt>
                  <dd class="font-mono break-all text-xs sm:text-sm mt-0.5"><%= @block && @block.merkleroot %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Chainwork</dt>
                  <dd class="font-mono break-all text-xs sm:text-sm mt-0.5"><%= @block && @block.chainwork %></dd>
                </div>
                <div>
                  <dt class="text-gray-500">Nonce</dt>
                  <dd class="font-mono break-all text-xs sm:text-sm mt-0.5"><%= @block && @block.nonce %></dd>
                </div>
              </dl>
            </div>
          </div>

          <h2 class="text-base sm:text-lg font-semibold mt-6 sm:mt-10 mb-3 sm:mb-4">
            Transactions included in this block
          </h2>

          <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
            <div class="overflow-x-auto">
              <table class="w-full text-xs sm:text-sm min-w-[640px]">
                <thead class="bg-gray-50 dark:bg-gray-700">
                  <tr>
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-left">HASH</th>
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-right">Public Input</th>
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-right">Public Output</th>
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-right">Δ Transparent</th>
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-left">TX Type</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                  <%= for tx <- @block && @block.tx || [] do %>
                    <% in_total = tx_in_total(tx, @full_cache) %>
                    <% out_total = tx_output_total(tx) %>
                    <% {delta, kind} = tx_delta(tx, in_total, out_total) %>
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                      <td class="px-2 sm:px-4 py-2 sm:py-4 font-mono text-indigo-600 hover:text-indigo-500">
                        <a href={tx_link(tx)} class="sm:hidden"><%= String.slice(tx.txid, 0, 10) %>…</a>
                        <a href={tx_link(tx)} class="hidden sm:inline"><%= tx.txid %></a>
                      </td>
                      <td class="px-2 sm:px-4 py-2 sm:py-4 text-right whitespace-nowrap">
                        <%= format_zec(in_total) %>
                      </td>
                      <td class="px-2 sm:px-4 py-2 sm:py-4 text-right whitespace-nowrap">
                        <%= format_zec(out_total) %>
                      </td>
                      <td class="px-2 sm:px-4 py-2 sm:py-4 text-right whitespace-nowrap">
                        <span class={delta_class(delta, kind)}>
                          <%= format_delta(delta, kind) %>
                        </span>
                      </td>
                      <td class="px-2 sm:px-4 py-2 sm:py-4">
                        <div class="flex items-center gap-1 sm:gap-1.5 flex-wrap">
                          <%= tx_type(tx) %>
                          <%= for badge <- pool_badges(tx) do %>
                            <%= badge %>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

defp miner_name(nil), do: nil

defp miner_name(block) do
  coinbase_hex = get_coinbase_hex(block)
  extract_miner_tag(coinbase_hex)
end

defp get_coinbase_hex(block) do
  tx = List.first(block.tx || [])

  vin =
    cond do
      is_map(tx) and Map.has_key?(tx, :vin) -> List.first(tx.vin || [])
      is_map(tx) and Map.has_key?(tx, "vin") -> List.first(tx["vin"] || [])
      true -> nil
    end

  cond do
    is_nil(vin) -> nil
    is_map(vin) -> Map.get(vin, :coinbase) || Map.get(vin, "coinbase")
    true -> nil
  end
end

defp extract_miner_tag(nil), do: nil
defp extract_miner_tag(""), do: nil

defp extract_miner_tag(hex) when is_binary(hex) do
  hex = String.replace(hex, ~r/[^0-9a-fA-F]/, "")

  case Base.decode16(hex, case: :mixed) do
    {:ok, bin} ->
      # Interpret as UTF-8 (emojis, pool names, etc.)
      string =
        case String.normalize(bin, :nfc) do
          s when is_binary(s) -> s
          _ -> :unicode.characters_to_binary(bin, :latin1, :utf8) |> to_string()
        end

      string
      # split on control / non-printable runs
      |> String.split(~r/[\x00-\x1F\x7F]+/u, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn s ->
        s == "" or Regex.match?(~r/^\d+$/u, s)
      end)
      |> List.last()

    _ ->
      nil
  end
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

  defp input_total(nil, _full_cache), do: 0.0

  defp input_total(block, full_cache) do
    (block.tx || [])
    |> Enum.reduce(0, fn tx, acc ->
      full = Map.get(full_cache, tx.txid) || %{}
      acc + calculate_vin_sum(full, full_cache)
    end)
    |> Kernel./(100_000_000.0)
  end

  defp output_total(nil), do: 0.0

  defp output_total(block) do
    (block.tx || [])
    |> Enum.reduce(0.0, fn tx, acc -> acc + tx_output_total(tx) end)
  end

  defp tx_output_total(nil), do: 0.0

  defp tx_output_total(tx) do
    Enum.reduce(tx.vout || [], 0.0, fn vout, acc -> acc + (vout.value || 0.0) end)
  end

  defp tx_in_total(tx, full_cache) do
    full = Map.get(full_cache, tx.txid) || %{}
    calculate_vin_sum(full, full_cache) / 100_000_000.0
  end

  defp tx_delta(tx, in_total, out_total) do
    pools = pool_list(tx)
    coinbase? = is_coinbase_struct?(tx)

    only_transparent? =
      (pools == [] or pools == ["transparent"]) and not coinbase?

    if only_transparent? do
      {abs(out_total - in_total), "fee"}
    else
      {out_total - in_total, "flow"}
    end
  end

  defp is_coinbase_struct?(tx) do
    vin = tx.vin || []
    vin != [] and (Map.get(hd(vin), :coinbase) != nil or Map.get(hd(vin), "coinbase") != nil)
  end

  defp format_delta(nil, _), do: "0.00000000"

  defp format_delta(n, "fee") when is_number(n),
    do: :erlang.float_to_binary(abs(n) * 1.0, decimals: 8)

  defp format_delta(n, _) when is_number(n) and n > 0,
    do: "+#{:erlang.float_to_binary(n * 1.0, decimals: 8)}"

  defp format_delta(n, _) when is_number(n),
    do: :erlang.float_to_binary(n * 1.0, decimals: 8)

  defp format_delta(_, _), do: "0.00000000"

  defp delta_class(_, "fee"), do: "text-gray-500"

  defp delta_class(n, _) when is_number(n) and n > 0.00000001,
    do: "text-emerald-600 dark:text-emerald-400"

  defp delta_class(n, _) when is_number(n) and n < -0.00000001,
    do: "text-amber-600 dark:text-amber-400"

  defp delta_class(_, _), do: "text-gray-500"

  defp tx_link(tx), do: "/transactions/#{tx.txid}"

  defp total_fees(nil, _full_cache), do: 0.0

  defp total_fees(block, full_cache) do
    Enum.reduce(block.tx || [], 0.0, fn tx, acc -> acc + tx_fee(tx, full_cache) end)
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
      ironwood = get_in(full, ["ironwood", "valueBalanceZat"]) || 0

      fee_zats = vin_sum - vout_sum - vpub_old + vpub_new + sapling + orchard + ironwood
      fee_zats / 100_000_000.0
    end
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
    Enum.reduce(full_tx["vout"] || [], 0, fn vout, acc -> acc + safe_zats(vout) end)
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
