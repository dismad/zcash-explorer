defmodule ZcashExplorer.Blocks.BlockWarmer do
  use Cachex.Warmer
  require Logger

  @max_blocks 400

  @doc """
  Returns the interval for this warmer.
  """
  def interval, do: :timer.seconds(15)

  @doc """
  Executes this cache warmer.
  """
  def execute(_state) do
    case Zcashex.getblockcount() do
      {:ok, n} ->
        start_height = max(0, n - @max_blocks + 1)

        blocks =
          Enum.to_list(start_height..n)
          |> Enum.map(fn x ->
            {:ok, block} = Zcashex.getblock(x, 2)
            block
          end)

        blocks
        |> Enum.map(fn x ->
          block_struct = Zcashex.Block.from_map(x)

          %{
            "height" => block_struct.height,
            "size" => block_struct.size,
            "hash" => block_struct.hash,
            "time" => ZcashExplorerWeb.Helpers.mined_time(block_struct.time),
            "tx_count" => length(block_struct.tx || []),
            "output_total" => ZcashExplorerWeb.Helpers.output_total(block_struct.tx || [])
          }
        end)
        |> Enum.sort(&(&1["height"] >= &2["height"]))
        |> handle_result

      {:error, reason} ->
        {:error, reason} |> handle_result
    end
  end

  # ignores the warmer result in case of error
  defp handle_result({:error, reason}) do
    Logger.error("Error while warming the block cache. #{inspect(reason)}")
    :ignore
  end

  defp handle_result(info) do
    {:ok, [{"block_cache", info}]}
  end
end