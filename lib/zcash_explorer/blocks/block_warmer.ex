defmodule ZcashExplorer.Blocks.BlockWarmer do
  use Cachex.Warmer
  require Logger

  @max_blocks 200

  @doc """
  Returns the interval for this warmer.
  """
  def interval, do: :timer.seconds(15)

  @doc """
  Executes this cache warmer.

  Incremental: keep blocks already cached and only fetch heights above the
  cached tip. A failed run must not pin the list, so on error we return the
  previous cache instead of :ignore-ing into staleness.
  """
  def execute(_state) do
    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) ->
        cached = read_cache()
        cached_tip = cached |> Enum.map(& &1["height"]) |> Enum.max(fn -> 0 end)
        from = max(cached_tip + 1, tip - @max_blocks + 1)

        new_blocks =
          if from <= tip do
            from..tip
            |> Enum.map(&fetch_summary/1)
            |> Enum.reject(&is_nil/1)
          else
            []
          end

        merged =
          (new_blocks ++ cached)
          |> Enum.uniq_by(& &1["height"])
          |> Enum.sort(&(&1["height"] >= &2["height"]))
          |> Enum.take(@max_blocks)

        if merged == [] do
          Logger.error("Block warmer: no blocks for tip #{tip}")
          :ignore
        else
          {:ok, [{"block_cache", merged}]}
        end

      {:error, reason} ->
        Logger.error("Block warmer: getblockcount failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.error("Block warmer: unexpected getblockcount: #{inspect(other)}")
        :ignore
    end
  end

  defp read_cache do
    case Cachex.get(:app_cache, "block_cache") do
      {:ok, data} when is_list(data) -> data
      _ -> []
    end
  end

  # Verbosity 1: header, time, nTx, txids. Enough for the list, and cheap
  # enough to keep up with the tip. Verbosity 2 was pulling every transaction
  # for 400 heights and the warmer stalled.
  defp fetch_summary(height) do
    case Zcashex.getblock(Integer.to_string(height), 1) do
      {:ok, block} when is_map(block) ->
        tx = block["tx"] || []

        %{
          "height" => block["height"],
          "size" => block["size"],
          "hash" => block["hash"],
          "time" => ZcashExplorerWeb.Helpers.mined_time(block["time"]),
          "tx_count" => block["nTx"] || length(tx),
          "output_total" => nil
        }

      other ->
        Logger.warning("Block warmer: getblock #{height} failed: #{inspect(other)}")
        nil
    end
  end
end
