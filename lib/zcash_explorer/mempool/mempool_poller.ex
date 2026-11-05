defmodule ZcashExplorer.Mempool.MempoolPoller do
  use GenServer
  require Logger

  import ZcashExplorerWeb.TransactionHelper

  @interval 5_000
  @concurrency 4
  @timeout 10_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    send(self(), :poll)
    {:ok, state}
  end

  def handle_info(:poll, previous) do
    new_state = poll(previous)
    Process.send_after(self(), :poll, @interval)
    {:noreply, new_state}
  end

  defp poll(previous) when is_map(previous) do
    Logger.info("MempoolPoller: cycle started")

    case Zcashex.getrawmempool(true) do
      {:ok, raw_mempool} when is_map(raw_mempool) ->
        current_txids = Map.keys(raw_mempool)
        Logger.info("MempoolPoller: node reports #{length(current_txids)} txs")

        previous_txids = Map.keys(previous)
        added = current_txids -- previous_txids
        removed = previous_txids -- current_txids

        Logger.info("MempoolPoller: #{length(added)} new, #{length(removed)} removed")

        newly_enriched = fetch_and_enrich(added, raw_mempool)

        enriched_map =
          previous
          |> Map.drop(removed)
          |> Map.take(current_txids)
          |> Map.merge(newly_enriched)

        list = Map.values(enriched_map)
        Cachex.put(:app_cache, "raw_mempool", list)
        Logger.info("MempoolPoller: wrote #{length(list)} txs to cache")
        enriched_map

      {:error, reason} ->
        Logger.error("MempoolPoller: getrawmempool failed: #{inspect(reason)}")
        previous

      other ->
        Logger.warning("MempoolPoller: unexpected getrawmempool: #{inspect(other)}")
        previous
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
            Logger.warning("MempoolPoller: getrawtransaction #{txid} failed: #{inspect(reason)}")
            {txid, fallback(txid, info)}
        end
      end,
      max_concurrency: @concurrency,
      timeout: @timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {txid, enriched}}, acc -> Map.put(acc, txid, enriched)
      {:exit, reason}, acc ->
        Logger.warning("MempoolPoller: task exit: #{inspect(reason)}")
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
