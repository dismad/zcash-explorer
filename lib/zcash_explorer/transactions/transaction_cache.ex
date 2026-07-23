defmodule ZcashExplorer.Transactions.TransactionWarmer do
  use Cachex.Warmer
  require Logger

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    case Zcashex.getblockcount() do
      {:ok, n} ->
        blocks =
          Enum.to_list((n - 20)..n)
          |> Enum.map(fn x ->
            {:ok, block} = Zcashex.getblock(x, 2)
            block
          end)

        blocks
        |> Enum.sort(&(&1["height"] >= &2["height"]))
        |> Enum.map(fn x -> x["tx"] end)
        |> List.flatten()
        |> Enum.take(20)
        |> Enum.map(fn y ->
          {:ok, tx} = Zcashex.getrawtransaction(y["txid"], 1)
          Zcashex.Transaction.from_map(tx)
        end)
        |> Enum.map(fn z ->
          out_total = ZcashExplorerWeb.Helpers.tx_out_total(z)
          in_total = tx_in_total(z)
          pools = ZcashExplorerWeb.TransactionHelper.pool_list(z)
          coinbase? = is_coinbase?(z)

          only_transparent? =
            (pools == [] or pools == ["transparent"]) and not coinbase?

          # Flipped sign: Out - In
          # Pure transparent → show fee (always ≥ 0)
          {delta, delta_kind} =
            if only_transparent? do
              {abs(out_total - in_total), "fee"}
            else
              {out_total - in_total, "flow"}
            end

          %{
            "txid" => Map.get(z, :txid),
            "block_height" => Map.get(z, :height),
            "time" => ZcashExplorerWeb.Helpers.mined_time(Map.get(z, :time)),
            "tx_in_total" => in_total,
            "tx_out_total" => out_total,
            "tx_delta" => delta,
            "delta_kind" => delta_kind,
            "size" => Map.get(z, :size),
            "type" => ZcashExplorerWeb.TransactionHelper.tx_type(z),
            "pools" => pools
          }
        end)
        |> handle_result

      {:error, reason} ->
        {:error, reason} |> handle_result
    end
  end

  defp tx_in_total(tx) do
    (tx.vin || [])
    |> Enum.reduce(0.0, fn vin, acc -> acc + vin_value(vin) end)
  end

  defp vin_value(vin) do
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

        case Zcashex.getrawtransaction(txid, 1) do
          {:ok, prev} ->
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

  defp is_coinbase?(tx) do
    vin = tx.vin || []
    vin != [] and (hd(vin).coinbase != nil)
  end

  defp handle_result({:error, reason}) do
    Logger.error("Error while warming the transaction cache. #{inspect(reason)}")
    :ignore
  end

  defp handle_result(info) do
    {:ok, [{"transaction_cache", info}]}
  end
end
