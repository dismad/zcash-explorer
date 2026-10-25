defmodule ZcashExplorer.Mempool.MempoolWarmer do
  use Cachex.Warmer
  require Logger

  import ZcashExplorerWeb.TransactionHelper

  @concurrency 4
  @timeout 10_000
  @agent_name __MODULE__.State

  def interval, do: :timer.seconds(5)

  def execute(_state) do
    Logger.info("MempoolWarmer: cycle started")

    ensure_agent()

    case Zcashex.getrawmempool(true) do
      {:ok, raw_mempool} when is_map(raw_mempool) ->
        current_txids = Map.keys(raw_mempool)
        Logger.info("MempoolWarmer: node reports #{length(current_txids)} txs")

        previous = Agent.get(@agent_name, & &1)
        previous_txids = Map.keys(previous)

        added = current_txids -- previous_txids
        removed = previous_txids -- current_txids

        Logger.info("MempoolWarmer: #{length(added)} new, #{length(removed)} removed")

        newly_enriched = fetch_and_enrich(added, raw_mempool)

        kept =
          previous
          |> Map.drop(removed)
          |> Map.take(current_txids)

        enriched_map = Map.merge(kept, newly_enriched)

        Agent.update(@agent_name, fn _ -> enriched_map end)

        list = Map.values(enriched_map)
        Logger.info("MempoolWarmer: writing #{length(list)} txs to cache")

        {:ok, [{"raw_mempool", list}]}

      {:error, reason} ->
        Logger.error("MempoolWarmer: getrawmempool failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.warning("MempoolWarmer: unexpected getrawmempool: #{inspect(other)}")
        :ignore
    end
  end

  defp ensure_agent do
    case Process.whereis(@agent_name) do
      nil ->
        Agent.start_link(fn -> %{} end, name: @agent_name)

      _pid ->
        :ok
    end
  end

  defp fetch_and_enrich([], _raw_mempool), do: %{}

  defp fetch_and_enrich(txids, raw_mempool) do
    txids
    |> Task.async_stream(
      fn txid ->
        info = Map.get(raw_mempool, txid, %{})

        case Zcashex.getrawtransaction(txid, 1) do
          {:ok, full_tx} ->
            {txid, enrich(txid, info, full_tx)}

          {:error, reason} ->
            Logger.warning("MempoolWarmer: getrawtransaction #{txid} failed: #{inspect(reason)}")
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
