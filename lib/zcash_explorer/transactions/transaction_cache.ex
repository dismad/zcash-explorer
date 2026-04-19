defmodule ZcashExplorer.Transactions.TransactionWarmer do
  use Cachex.Warmer
  require Logger

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    case Zcashex.getblockcount() do
      {:ok, n} ->
        blocks =
          Enum.to_list((n - 20)..n)
          |> Enum.map(fn height ->
            {:ok, block} = Zcashex.getblock(height, 2)
            block
          end)

        recent_txs =
          blocks
          |> Enum.sort_by(& &1["height"], :desc)
          |> Enum.flat_map(& &1["tx"])
          |> Enum.take(20)
          |> Enum.map(fn tx_map ->
            {:ok, full_tx} = Zcashex.getrawtransaction(tx_map["txid"], 1)
            tx = Zcashex.Transaction.from_map(full_tx)

            type = ZcashExplorerWeb.TransactionHelper.tx_type(tx)

            %{
              "txid" => tx.txid,
              "block_height" => tx.height,
              "time" => tx.time,
              "tx_out_total" => ZcashExplorerWeb.Helpers.tx_out_total(tx),
              "size" => tx.size,
              "type" => type
            }
          end)

        Logger.info("✅ TransactionWarmer: Saved #{length(recent_txs)} transactions with types")
        {:ok, [{"transaction_cache", recent_txs}]}

      {:error, reason} ->
        Logger.error("TransactionWarmer failed: #{inspect(reason)}")
        :ignore
    end
  end
end