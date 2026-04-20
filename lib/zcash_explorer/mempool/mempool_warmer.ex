defmodule ZcashExplorer.Mempool.MempoolWarmer do
  use Cachex.Warmer
  require Logger
  import ZcashExplorerWeb.TransactionHelper

  def interval, do: :timer.seconds(5)

  def execute(_state) do
    case Zcashex.getrawmempool(true) do
      {:ok, raw_mempool} ->
        mempool_info =
          Enum.map(raw_mempool, fn {txid, info} ->
            type =
              case Zcashex.getrawtransaction(txid, 1) do
                {:ok, full_tx} ->
                  tx = Zcashex.Transaction.from_map(full_tx)
                  tx_type(tx)

                {:error, reason} ->
                  Logger.error(
                    "MempoolWarmer: Failed to fetch full tx #{txid}: #{inspect(reason)}"
                  )

                  "unknown"
              end

            %{
              "txid" => txid,
              "info" => info,
              "type" => type
            }
          end)

        Logger.info(
          "✅ MempoolWarmer: Saved #{length(mempool_info)} transactions with correct types"
        )

        {:ok, [{"raw_mempool", mempool_info}]}

      {:error, reason} ->
        Logger.error("MempoolWarmer failed: #{inspect(reason)}")
        :ignore
    end
  end
end
