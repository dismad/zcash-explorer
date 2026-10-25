defmodule ZcashExplorer.Mempool.MempoolWarmer do
  use Cachex.Warmer
  require Logger

  import ZcashExplorerWeb.TransactionHelper

  @concurrency 6
  @timeout 5_000
  @enriched_key "raw_mempool_enriched"

  def interval, do: :timer.seconds(5)

  def execute(_state) do
    case Zcashex.getrawmempool(true) do
      {:ok, raw_mempool} when is_map(raw_mempool) ->
        current_txids = Map.keys(raw_mempool)

        previous =
          case Cachex.get(:app_cache, @enriched_key) do
            {:ok, %{} = map} -> map
            _ -> %{}
          end

        previous_txids = Map.keys(previous)

        added = current_txids -- previous_txids
        removed = previous_txids -- current_txids

        newly_enriched =
          added
          |> Task.async_stream(
            fn txid ->
              info = Map.get(raw_mempool, txid)

              case Zcashex.getrawtransaction(txid, 1) do
                {:ok, full_tx} ->
                  {txid, enrich(txid, info, full_tx)}

                {:error, reason} ->
                  Logger.warning("MempoolWarmer: failed to fetch #{txid}: #{inspect(reason)}")
                  {txid, fallback(txid, info)}
              end
            end,
            max_concurrency: @concurrency,
            timeout: @timeout,
            on_timeout: :kill_task
          )
          |> Enum.reduce(%{}, fn
            {:ok, {txid, enriched}}, acc ->
              Map.put(acc, txid, enriched)

            {:exit, reason}, acc ->
              Logger.warning("MempoolWarmer: task exit: #{inspect(reason)}")
              acc
          end)

        kept =
          previous
          |> Map.drop(removed)
          |> Map.take(current_txids)

        enriched_map = Map.merge(kept, newly_enriched)

        # Persist for next cycle
        Cachex.put(:app_cache, @enriched_key, enriched_map)

        # List the LiveView already expects
        list = Map.values(enriched_map)

        Logger.info(
          "MempoolWarmer: #{length(list)} txs (#{length(added)} new, #{length(removed)} removed)"
        )

        {:ok, [{"raw_mempool", list}]}

      {:error, reason} ->
        Logger.error("MempoolWarmer failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.warning("MempoolWarmer: unexpected getrawmempool result: #{inspect(other)}")
        :ignore
    end
  end

  defp enrich(txid, info, full_tx) do
    tx = Zcashex.Transaction.from_map(full_tx)
    pools = pool_list(tx)
    coinbase? = is_coinbase_tx?(tx)

    type =
      if coinbase? do
        "coinbase"
      else
        classify(tx)
      end

    turnstile? = turnstile?(tx)
    turnstile_zat = turnstile_amount_zats(tx)
    ironwood_actions = ironwood_action_count(tx)

    %{
      "txid" => txid,
      "info" => info,
      "type" => type,
      "pools" => pools,
      "is_coinbase" => coinbase?,
      "turnstile" => turnstile?,
      "turnstile_zat" => turnstile_zat,
      "turnstile_zec" => turnstile_zat / 100_000_000.0,
      "ironwood_actions" => ironwood_actions
    }
  end

  defp fallback(txid, info) do
    %{
      "txid" => txid,
      "info" => info,
      "type" => "unknown",
      "pools" => [],
      "is_coinbase" => false,
      "turnstile" => false,
      "turnstile_zat" => 0,
      "turnstile_zec" => 0.0,
      "ironwood_actions" => 0
    }
  end

  defp is_coinbase_tx?(tx) when is_map(tx) do
    vin = Map.get(tx, :vin) || Map.get(tx, "vin") || []

    case vin do
      [first | _] when is_map(first) ->
        Map.get(first, :coinbase) != nil or Map.get(first, "coinbase") != nil

      _ ->
        false
    end
  end

  defp is_coinbase_tx?(_), do: false
end
