defmodule ZcashExplorer.Blocks.BlockWarmer do
  use Cachex.Warmer
  require Logger

  @max_blocks 400
  @cache_key "block_cache"
  @state_key "block_warmer_state"

  def interval, do: :timer.seconds(1)

  def execute(_state) do
    Logger.info("BlockWarmer: cycle started")

    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) ->
        previous_state =
          case Cachex.get(:app_cache, @state_key) do
            {:ok, %{last_height: h, blocks: blocks}} when is_integer(h) and is_list(blocks) ->
              %{last_height: h, blocks: blocks}

            _ ->
              %{last_height: -1, blocks: []}
          end

        last_height = previous_state.last_height
        existing = previous_state.blocks

        new_blocks =
          if last_height < 0 do
            # First run: fetch the window once
            start_height = max(0, tip - @max_blocks + 1)
            Logger.info("BlockWarmer: first run, fetching #{start_height}..#{tip}")
            fetch_range(start_height, tip)
          else
            # Incremental: only new blocks
            from = last_height + 1
            if from <= tip do
              Logger.info("BlockWarmer: fetching new blocks #{from}..#{tip}")
              fetch_range(from, tip)
            else
              []
            end
          end

        updated =
          (existing ++ new_blocks)
          |> Enum.uniq_by(& &1["height"])
          |> Enum.sort_by(& &1["height"], :desc)
          |> Enum.take(@max_blocks)

        Cachex.put(:app_cache, @state_key, %{last_height: tip, blocks: updated})

        Logger.info("BlockWarmer: writing #{length(updated)} blocks (tip #{tip})")

        {:ok, [{@cache_key, updated}]}

      {:error, reason} ->
        Logger.error("BlockWarmer: getblockcount failed: #{inspect(reason)}")
        :ignore

      other ->
        Logger.warning("BlockWarmer: unexpected getblockcount: #{inspect(other)}")
        :ignore
    end
  end

  defp fetch_range(from, to) when from > to, do: []

  defp fetch_range(from, to) do
    from..to
    |> Enum.map(fn height ->
      case Zcashex.getblock(height, 1) do
        {:ok, block} when is_map(block) ->
          %{
            "height" => block["height"] || height,
            "size" => block["size"],
            "hash" => block["hash"],
            "time" => ZcashExplorerWeb.Helpers.mined_time(block["time"]),
            "tx_count" => length(block["tx"] || []),
            "output_total" => 0.0
          }

        other ->
          Logger.warning("BlockWarmer: getblock #{height} failed: #{inspect(other)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
