defmodule ZcashExplorer.Transactions.TransactionWarmer do
  use Cachex.Warmer
  require Logger

  @rpc_timeout 60_000

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    case safe_call(fn -> Zcashex.getblockcount() end) do
      {:ok, n} when is_integer(n) ->
        blocks =
          Enum.to_list((n - 20)..n)
          |> Enum.map(fn height ->
            case safe_call(fn -> Zcashex.getblock(height, 2) end) do
              {:ok, block} when is_map(block) -> block
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        blocks
        |> Enum.sort(&(&1["height"] >= &2["height"]))
        |> Enum.map(fn x -> x["tx"] || [] end)
        |> List.flatten()
        |> Enum.take(20)
        |> Enum.map(fn y ->
          txid = y["txid"] || y[:txid]

          case safe_call(fn -> Zcashex.getrawtransaction(txid, 1) end) do
            {:ok, tx} when is_map(tx) -> Zcashex.Transaction.from_map(tx)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn z ->
          out_total = ZcashExplorerWeb.Helpers.tx_out_total(z)
          in_total = tx_in_total(z)
          pools = ZcashExplorerWeb.TransactionHelper.pool_list(z)
          coinbase? = is_coinbase?(z)

          only_transparent? =
            (pools == [] or pools == ["transparent"]) and not coinbase?

          {delta, delta_kind} =
            if only_transparent? do
              {abs(out_total - in_total), "fee"}
            else
              {out_total - in_total, "flow"}
            end

          type_name =
            if coinbase? do
              "coinbase"
            else
              ZcashExplorerWeb.TransactionHelper.classify(z)
            end

          turnstile? = ZcashExplorerWeb.TransactionHelper.turnstile?(z)
          turnstile_zat = ZcashExplorerWeb.TransactionHelper.turnstile_amount_zats(z)

          %{
            "txid" => Map.get(z, :txid),
            "block_height" => Map.get(z, :height),
            "time" => ZcashExplorerWeb.Helpers.mined_time(Map.get(z, :time)),
            "tx_in_total" => in_total,
            "tx_out_total" => out_total,
            "tx_delta" => delta,
            "delta_kind" => delta_kind,
            "size" => Map.get(z, :size),
            # STRING type name only — never HTML from tx_type/1
            "type" => type_name,
            "pools" => pools,
            "is_coinbase" => coinbase?,
            "turnstile" => turnstile?,
            "turnstile_zat" => turnstile_zat,
            "turnstile_zec" => turnstile_zat / 100_000_000.0
          }
        end)
        |> handle_result()

      {:error, reason} ->
        Logger.warning("TransactionWarmer: getblockcount failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.warning("TransactionWarmer: unexpected getblockcount result: #{inspect(other)}")
        :ignore
    end
  end

  # Use Zcashex.* APIs (correct params) with a timeout; never kill the warmer on exit.
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

  defp tx_in_total(tx) do
    (Map.get(tx, :vin) || Map.get(tx, "vin") || [])
    |> Enum.reduce(0.0, fn vin, acc -> acc + vin_value(vin) end)
  end

  defp vin_value(vin) when is_map(vin) do
    cond do
      Map.get(vin, :coinbase) != nil or Map.get(vin, "coinbase") != nil ->
        0.0

      is_number(Map.get(vin, :value)) ->
        Map.get(vin, :value)

      is_number(Map.get(vin, "value")) ->
        Map.get(vin, "value")

      is_number(Map.get(vin, :valueZat)) ->
        Map.get(vin, :valueZat) / 100_000_000.0

      is_number(Map.get(vin, "valueZat")) ->
        Map.get(vin, "valueZat") / 100_000_000.0

      is_binary(Map.get(vin, :txid) || Map.get(vin, "txid")) ->
        txid = Map.get(vin, :txid) || Map.get(vin, "txid")
        vout_idx = Map.get(vin, :vout) || Map.get(vin, "vout")

        case safe_call(fn -> Zcashex.getrawtransaction(txid, 1) end) do
          {:ok, prev} when is_map(prev) ->
            vouts = prev["vout"] || []
            out = Enum.at(vouts, vout_idx || 0) || %{}
            (out["value"] || 0.0) * 1.0

          _ ->
            0.0
        end

      true ->
        0.0
    end
  end

  defp vin_value(_), do: 0.0

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

  defp handle_result({:error, reason}) do
    Logger.error("Error while warming the transaction cache. #{inspect(reason)}")
    :ignore
  end

  defp handle_result(info) when is_list(info) do
    Logger.info("TransactionWarmer: Saved #{length(info)} transactions with correct types")
    {:ok, [{"transaction_cache", info}]}
  end
end
