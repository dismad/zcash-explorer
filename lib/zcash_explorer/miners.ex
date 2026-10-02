defmodule ZcashExplorer.Miners do
  @moduledoc """
  Aggregate recent coinbase payouts into a miner ranking.

  Window columns (blocks, share, fees, window ZEC) come from one `getblock`
  verbosity-1 call per height, then the coinbase transaction. Blocks mined is
  the largest coinbase output only. Smaller outputs in the same coinbase are
  funding streams and do not increment the block count. Fees are the excess of
  a block payout over the most common payout in the window.

  `historic_coinbase/2` is the ZEC mined figure: every coinbase output paid to
  the address from height 1 through tip. Spends are not subtracted, and
  non-coinbase receives are not included.
  """

  def scan(window) when is_integer(window) and window > 0 do
    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) ->
        from = max(tip - window + 1, 1)
        heights = Enum.to_list(from..tip)
        acc = Enum.reduce(heights, empty(tip, from), &add_height(&2, &1))
        {:ok, finalize(acc)}

      other ->
        {:error, other}
    end
  end

  def empty(tip \\ nil, from \\ nil) do
    %{
      tip: tip,
      from: from,
      scanned: 0,
      miners: %{},
      block_payouts: [],
      total_mined_zat: 0,
      total_fees_zat: 0,
      total_txs: 0
    }
  end

  def add_height(acc, height) do
    try do
      case Zcashex.getblock(Integer.to_string(height), 1) do
        {:ok, block} when is_map(block) -> add_block(acc, height, block)
        _ -> %{acc | scanned: acc.scanned + 1}
      end
    catch
      :exit, _ -> %{acc | scanned: acc.scanned + 1}
    end
  end

  def add_block(acc, _height, block) do
    user_txs = max(tx_count(block) - 1, 0)
    outputs = coinbase_outputs(block)
    paid = Enum.reduce(outputs, 0, fn o, n -> n + o.zat end)
    miner = Enum.max_by(outputs, & &1.zat, fn -> nil end)

    miners =
      Enum.reduce(outputs, acc.miners, fn output, miners ->
        Map.update(miners, output.address, new_miner(output.address), fn row ->
          %{row | mined_zat: row.mined_zat + output.zat, payouts: row.payouts + 1}
        end)
      end)

    miners =
      if miner do
        Map.update(miners, miner.address, new_miner(miner.address), fn row ->
          %{row | blocks: row.blocks + 1, txs: row.txs + user_txs}
        end)
      else
        miners
      end

    %{
      acc
      | scanned: acc.scanned + 1,
        miners: miners,
        block_payouts: if(miner, do: [{miner.address, paid} | acc.block_payouts], else: acc.block_payouts),
        total_mined_zat: acc.total_mined_zat + paid,
        total_txs: acc.total_txs + user_txs
    }
  end

  def finalize(acc) do
    {miners, total_fees} = assign_fees(acc.miners, Map.get(acc, :block_payouts, []))

    ranked =
      miners
      |> Map.values()
      |> Enum.filter(&(&1.blocks > 0))
      |> Enum.sort_by(&{&1.blocks, &1.mined_zat}, :desc)
      |> Enum.take(100)
      |> Enum.with_index(1)
      |> Enum.map(fn {miner, rank} ->
        share =
          if acc.total_mined_zat > 0 do
            miner.mined_zat / acc.total_mined_zat
          else
            0.0
          end

        Map.merge(miner, %{
          rank: rank,
          share: share,
          color: color(miner.address),
          historic_mined_zat: nil
        })
      end)

    funding =
      miners
      |> Map.values()
      |> Enum.filter(&(&1.blocks == 0 and &1.mined_zat > 0))
      |> Enum.sort_by(& &1.mined_zat, :desc)

    acc
    |> Map.put(:miners, miners)
    |> Map.put(:total_fees_zat, total_fees)
    |> Map.put(:funding, funding)
    |> Map.put(:ranked, ranked)
  end

  # Excess over the modal block payout. Feature-net issuance is not the
  # mainnet pre-halving subsidy, which was clamping every fee to zero.
  defp assign_fees(miners, payouts) do
    base =
      payouts
      |> Enum.map(fn {_address, paid} -> paid end)
      |> Enum.frequencies()
      |> Enum.max_by(fn {_paid, count} -> count end, fn -> {0, 0} end)
      |> elem(0)

    Enum.reduce(payouts, {miners, 0}, fn {address, paid}, {miners, total} ->
      fee = max(paid - base, 0)

      miners =
        Map.update(miners, address, new_miner(address), fn row ->
          %{row | fees_zat: row.fees_zat + fee}
        end)

      {miners, total + fee}
    end)
  end

  defp new_miner(address) do
    %{address: address, blocks: 0, payouts: 0, txs: 0, mined_zat: 0, fees_zat: 0}
  end

  defp tx_count(%{"nTx" => n}) when is_integer(n), do: n
  defp tx_count(%{"tx" => txs}) when is_list(txs), do: length(txs)
  defp tx_count(_), do: 1

  defp coinbase_outputs(block) do
    case coinbase_tx(block) do
      nil ->
        []

      tx ->
        (tx["vout"] || [])
        |> Enum.map(fn vout ->
          %{address: address_of(vout), zat: zats(vout)}
        end)
        |> Enum.reject(&(&1.zat <= 0))
        |> case do
          [] -> [%{address: "shielded-coinbase", zat: 0}]
          outputs -> outputs
        end
    end
  end

  defp coinbase_tx(%{"tx" => [first | _]}) when is_map(first), do: first

  defp coinbase_tx(%{"tx" => [txid | _]}) when is_binary(txid) do
    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx} when is_map(tx) -> tx
      _ -> nil
    end
  end

  defp coinbase_tx(_), do: nil

  defp address_of(%{"scriptPubKey" => script}) when is_map(script) do
    cond do
      is_binary(script["address"]) ->
        script["address"]

      is_list(script["addresses"]) and script["addresses"] != [] ->
        hd(script["addresses"])

      true ->
        "shielded-coinbase"
    end
  end

  defp address_of(_), do: "shielded-coinbase"

  defp zats(%{"valueZat" => n}) when is_integer(n), do: n
  defp zats(%{"value" => n}) when is_number(n), do: round(n * 100_000_000)
  defp zats(_), do: 0

  defp color(address) do
    hue = :erlang.phash2(address, 360)
    "hsl(#{hue}, 72%, 46%)"
  end
  @doc """
  Lifetime coinbase paid to `address` from height 1 through `tip`.
  Returns `%{zat: integer, blocks: integer}`. Spends are not subtracted.
  Blocks use the same rule as the window table: largest coinbase output only.
  """
  def historic_coinbase(address, tip) when is_binary(address) and is_integer(tip) and tip > 0 do
    case historic_cached(address, tip) do
      {:ok, %{zat: zat, blocks: blocks}} when is_integer(zat) and is_integer(blocks) ->
        %{zat: zat, blocks: blocks}

      _ ->
        stats = fetch_historic(address, tip)
        historic_store(address, tip, stats)
        stats
    end
  end

  def historic_coinbase(_, _), do: %{zat: 0, blocks: 0}

  def peek_historic(address, tip) when is_binary(address) and is_integer(tip) and tip > 0 do
    case historic_cached(address, tip) do
      {:ok, %{zat: zat, blocks: blocks}} when is_integer(zat) and is_integer(blocks) ->
        %{zat: zat, blocks: blocks}

      _ ->
        nil
    end
  end

  def peek_historic(_, _), do: nil

  def pays?(vout, address) when is_map(vout) and is_binary(address) do
    script = vout["scriptPubKey"] || %{}

    cond do
      script["address"] == address ->
        true

      is_list(script["addresses"]) and address in script["addresses"] ->
        true

      true ->
        false
    end
  end

  def pays?(_, _), do: false

  defp fetch_historic(address, tip) do
    try do
      case Zcashex.getaddresstxids(address, 1, tip) do
        {:ok, txids} when is_list(txids) ->
          Enum.reduce(Enum.uniq(txids), %{zat: 0, blocks: 0}, fn txid, acc ->
            add_historic(acc, coinbase_paid(txid, address))
          end)

        _ ->
          %{zat: 0, blocks: 0}
      end
    catch
      :exit, _ -> %{zat: 0, blocks: 0}
    end
  end

  defp add_historic(acc, %{zat: zat, block: true}) when zat > 0 do
    %{acc | zat: acc.zat + zat, blocks: acc.blocks + 1}
  end

  defp add_historic(acc, %{zat: zat}) when is_integer(zat) do
    %{acc | zat: acc.zat + zat}
  end

  defp add_historic(acc, _), do: acc

  defp coinbase_paid(txid, address) when is_binary(txid) do
    try do
      case Zcashex.getrawtransaction(txid, 1) do
        {:ok, tx} when is_map(tx) ->
          if coinbase?(tx) do
            outputs = paid_outputs(tx)
            zat = Enum.reduce(outputs, 0, fn o, n -> if o.address == address, do: n + o.zat, else: n end)
            largest = Enum.max_by(outputs, & &1.zat, fn -> nil end)
            %{zat: zat, block: largest != nil and largest.address == address and zat > 0}
          else
            %{zat: 0, block: false}
          end

        _ ->
          %{zat: 0, block: false}
      end
    catch
      :exit, _ -> %{zat: 0, block: false}
    end
  end

  defp coinbase_paid(_, _), do: %{zat: 0, block: false}

  defp paid_outputs(tx) do
    (tx["vout"] || [])
    |> Enum.map(fn vout -> %{address: address_of(vout), zat: zats(vout)} end)
    |> Enum.reject(&(&1.zat <= 0 or &1.address == "shielded-coinbase"))
  end

  defp coinbase?(%{"vin" => vins}) when is_list(vins), do: Enum.any?(vins, &Map.has_key?(&1, "coinbase"))
  defp coinbase?(_), do: false

  defp paid_to(tx, address) do
    (tx["vout"] || [])
    |> Enum.reduce(0, fn vout, n ->
      if pays?(vout, address), do: n + zats(vout), else: n
    end)
  end

  defp historic_key(address, tip), do: "miner-historic:" <> address <> ":" <> Integer.to_string(tip)

  defp historic_cached(address, tip) do
    try do
      Cachex.get(:app_cache, historic_key(address, tip))
    catch
      _, _ -> :miss
    end
  end

  defp historic_store(address, tip, zat) do
    try do
      Cachex.put(:app_cache, historic_key(address, tip), zat)
    catch
      _, _ -> :ok
    end
  end
end
