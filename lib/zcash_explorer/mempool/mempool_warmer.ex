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
            {type, pools, coinbase?} =
              case Zcashex.getrawtransaction(txid, 1) do
                {:ok, full_tx} ->
                  tx = Zcashex.Transaction.from_map(full_tx)
                  pools = pool_list(tx)
                  coinbase? = is_coinbase_tx?(tx)

                  type =
                    if coinbase? do
                      "coinbase"
                    else
                      classify(tx)
                    end

                  {type, pools, coinbase?}

                {:error, reason} ->
                  Logger.error(
                    "MempoolWarmer: Failed to fetch full tx #{txid}: #{inspect(reason)}"
                  )

                  {"unknown", [], false}
              end

            %{
              "txid" => txid,
              "info" => info,
              # STRING type only — never tx_type/1 HTML
              "type" => type,
              "pools" => pools,
              "is_coinbase" => coinbase?
            }
          end)

        Logger.info(
          "MempoolWarmer: Saved #{length(mempool_info)} transactions with correct types"
        )

        {:ok, [{"raw_mempool", mempool_info}]}

      {:error, reason} ->
        Logger.error("MempoolWarmer failed: #{inspect(reason)}")
        :ignore
    end
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
