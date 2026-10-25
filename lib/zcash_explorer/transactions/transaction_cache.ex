defmodule ZcashExplorer.Transactions.TransactionWarmer do
  use Cachex.Warmer
  require Logger

  @rpc_timeout 15_000
  @max_txs 20
  @cache_key "transaction_cache"
  @state_key "tx_warmer_state"

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    Logger.info("TransactionWarmer: cycle started")

    case safe_call(fn -> Zcashex.getblockcount() end) do
      {:ok, tip} when is_integer(tip) ->
        previous =
          case Cachex.get(:app_cache, @state_key) do
            {:ok, %{last_height: h, txs: txs}} when is_integer(h) and is_list(txs) ->
              %{last_height: h, txs: txs}

            _ ->
              %{last_height: -1, txs: []}
          end

        # Only look at the most recent blocks needed to fill @max_txs
        from = max(0, tip - 30)
        new_txs =
          if previous.last_height < tip do
            fetch_recent_txs(from, tip)
          else
            previous.txs
          end

        updated =
          (new_txs ++ previous.txs)
          |> Enum.uniq_by(& &1["txid"])
          |> Enum.take(@max_txs)

        Cachex.put(:app_cache, @state_key, %{last_height: tip, txs: updated})

        Logger.info("TransactionWarmer: writing #{length(updated)} txs (tip #{tip})")

        {:ok, [{@cache_key, updated}]}

      {:error, reason} ->
        Logger.warning("TransactionWarmer: getblockcount failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.warning("TransactionWarmer: unexpected result: #{inspect(other)}")
        :ignore
    end
  end

  defp fetch_recent_txs(from, to) do
    from..to
    |> Enum.reverse()
    |> Enum.reduce_while([], fn height, acc ->
      if length(acc) >= @max_txs do
        {:halt, acc}
      else
        case safe_call(fn -> Zcashex.getblock(height, 2) end) do
          {:ok, block} when is_map(block) ->
            txs =
              (block["tx"] || [])
              |> Enum.map(fn raw ->
                txid = raw["txid"] || raw[:txid]

                case safe_call(fn -> Zcashex.getrawtransaction(txid, 1) end) do
                  {:ok, full} when is_map(full) ->
                    build_tx(full, height)

                  _ ->
                    nil
                end
              end)
              |> Enum.reject(&is_nil/1)

            {:cont, acc ++ txs}

          _ ->
            {:cont, acc}
        end
      end
    end)
    |> Enum.take(@max_txs)
  end

  defp build_tx(full, height) do
    z = Zcashex.Transaction.from_map(full)
    pools = ZcashExplorerWeb.TransactionHelper.pool_list(z)
    coinbase? = is_coinbase?(z)

    type_name =
      if coinbase? do
        "coinbase"
      else
        ZcashExplorerWeb.TransactionHelper.classify(z)
      end

    %{
      "txid" => Map.get(z, :txid),
      "block_height" => height,
      "time" => ZcashExplorerWeb.Helpers.mined_time(Map.get(z, :time)),
      "tx_in_total" => 0.0,
      "tx_out_total" => ZcashExplorerWeb.Helpers.tx_out_total(z),
      "tx_delta" => 0.0,
      "delta_kind" => "flow",
      "size" => Map.get(z, :size),
      "type" => type_name,
      "pools" => pools,
      "is_coinbase" => coinbase?,
      "turnstile" => ZcashExplorerWeb.TransactionHelper.turnstile?(z),
      "turnstile_zat" => ZcashExplorerWeb.TransactionHelper.turnstile_amount_zats(z),
      "ironwood_actions" => ZcashExplorerWeb.TransactionHelper.ironwood_action_count(z)
    }
  end

  defp safe_call(fun) when is_function(fun, 0) do
    task = Task.async(fun)

    case Task.yield(task, @rpc_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, other} -> {:error, other}
      nil -> {:error, :timeout}
    end
  catch
    :exit, reason -> {:error, reason}
  end

  defp is_coinbase?(tx) when is_map(tx) do
    vin = Map.get(tx, :vin) || Map.get(tx, "vin") || []

    case vin do
      [first | _] when is_map(first) ->
        Map.get(first, :coinbase) != nil or Map.get(first, "coinbase") != nil

      _ ->
        false
    end
  end

  defp is_coinbase?(_), do: false
end
