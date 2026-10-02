defmodule ZcashExplorer.Miners do
  @moduledoc """
  Aggregate recent coinbase payouts into a miner ranking.

  One `getblock` verbosity-2 call per height. Fees are coinbase value above
  the consensus subsidy (80% before the first halving, full subsidy after).
  """

  @subsidy_zats 1_250_000_000
  @first_halving 1_046_400
  @halving_interval 1_680_000

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
      total_mined_zat: 0,
      total_fees_zat: 0,
      total_txs: 0
    }
  end

  def add_height(acc, height) do
    case Zcashex.getblock(Integer.to_string(height), 2) do
      {:ok, block} when is_map(block) -> add_block(acc, height, block)
      _ -> %{acc | scanned: acc.scanned + 1}
    end
  end

  def add_block(acc, height, block) do
    tx_count = tx_count(block)
    user_txs = max(tx_count - 1, 0)
    outputs = coinbase_outputs(block)
    subsidy = subsidy_zats(height)
    paid = Enum.reduce(outputs, 0, fn o, n -> n + o.zat end)
    fees = max(paid - subsidy, 0)

    miners =
      Enum.reduce(outputs, acc.miners, fn output, miners ->
        share = if paid > 0, do: output.zat / paid, else: 0
        fee_share = round(fees * share)

        Map.update(miners, output.address, new_miner(output.address), fn miner ->
          %{
            miner
            | blocks: miner.blocks + 1,
              txs: miner.txs + user_txs,
              mined_zat: miner.mined_zat + output.zat,
              fees_zat: miner.fees_zat + fee_share
          }
        end)
      end)

    %{
      acc
      | scanned: acc.scanned + 1,
        miners: miners,
        total_mined_zat: acc.total_mined_zat + paid,
        total_fees_zat: acc.total_fees_zat + fees,
        total_txs: acc.total_txs + user_txs
    }
  end

  def finalize(acc) do
    ranked =
      acc.miners
      |> Map.values()
      |> Enum.sort_by(& &1.mined_zat, :desc)
      |> Enum.take(100)
      |> Enum.with_index(1)
      |> Enum.map(fn {miner, rank} ->
        share =
          if acc.total_mined_zat > 0 do
            miner.mined_zat / acc.total_mined_zat
          else
            0.0
          end

        Map.merge(miner, %{rank: rank, share: share, color: color(miner.address)})
      end)

    Map.put(acc, :ranked, ranked)
  end

  def subsidy_zats(height) when is_integer(height) and height >= 0 do
    halvings =
      if height < @first_halving do
        0
      else
        1 + div(height - @first_halving, @halving_interval)
      end

    subsidy = div(@subsidy_zats, Integer.pow(2, min(halvings, 28)))
    if height < @first_halving, do: div(subsidy * 4, 5), else: subsidy
  end

  defp new_miner(address) do
    %{address: address, blocks: 0, txs: 0, mined_zat: 0, fees_zat: 0}
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
    hue =
      :erlang.phash2(address, 360)

    "hsl(#{hue}, 72%, 46%)"
  end
end
