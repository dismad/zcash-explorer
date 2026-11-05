defmodule ZcashExplorer.Transactions.TransactionPoller do
  use GenServer
  require Logger

  @interval 10_000
  @max_txs 20
  @rpc_timeout 15_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{last_height: -1, txs: []}, name: __MODULE__)
  end

  def init(state) do
    send(self(), :poll)
    {:ok, state}
  end

  def handle_info(:poll, state) do
    new_state = poll(state)
    Process.send_after(self(), :poll, @interval)
    {:noreply, new_state}
  end

  defp poll(%{last_height: last_height, txs: existing} = state) do
    Logger.info("TransactionPoller: cycle started")

    case safe_call(fn -> Zcashex.getblockcount() end) do
      {:ok, tip} when is_integer(tip) ->
        new_txs =
          if last_height < tip do
            from = max(0, tip - 30)
            Logger.info("TransactionPoller: fetching recent txs from #{from}..#{tip}")
            fetch_recent_txs(from, tip)
          else
            Logger.info("TransactionPoller: tip unchanged (#{tip})")
            []
          end

        updated =
          (new_txs ++ existing)
          |> Enum.uniq_by(& &1["txid"])
          |> Enum.take(@max_txs)

        Cachex.put(:app_cache, "transaction_cache", updated)
        Logger.info("TransactionPoller: wrote #{length(updated)} txs (tip #{tip})")
        %{last_height: tip, txs: updated}

      {:error, reason} ->
        Logger.warning("TransactionPoller: getblockcount failed: #{inspect(reason)}")
        state

      other ->
        Logger.warning("TransactionPoller: unexpected result: #{inspect(other)}")
        state
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
                  {:ok, full} when is_map(full) -> build_tx(full, height)
                  _ -> nil
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
