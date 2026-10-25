defmodule ZcashExplorer.Blocks.BlockWarmer do
  use Cachex.Warmer
  require Logger

  @max_blocks 200
  @cache_key "block_cache"
  @agent_name __MODULE__.State

  def interval, do: :timer.seconds(2)

  def execute(_state) do
    Logger.info("BlockWarmer: cycle started")

    ensure_agent()

    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) ->
        %{last_height: last_height, blocks: existing} = Agent.get(@agent_name, & &1)

        new_blocks =
          cond do
            last_height < 0 ->
              # Smaller initial window so the first cycle finishes quickly
              start_height = max(0, tip - 50)
              Logger.info("BlockWarmer: first run, fetching #{start_height}..#{tip}")
              fetch_range(start_height, tip)

            last_height < tip ->
              from = last_height + 1
              Logger.info("BlockWarmer: fetching new blocks #{from}..#{tip}")
              fetch_range(from, tip)

            true ->
              Logger.info("BlockWarmer: tip unchanged (#{tip})")
              []
          end

        updated =
          (existing ++ new_blocks)
          |> Enum.uniq_by(& &1["height"])
          |> Enum.sort_by(& &1["height"], :desc)
          |> Enum.take(@max_blocks)

        Agent.update(@agent_name, fn _ -> %{last_height: tip, blocks: updated} end)

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

  defp ensure_agent do
    case Process.whereis(@agent_name) do
      nil ->
        {:ok, _} = Agent.start_link(fn -> %{last_height: -1, blocks: []} end, name: @agent_name)
        :ok

      _pid ->
        :ok
    end
  end

  defp fetch_range(from, to) when from > to, do: []

  defp fetch_range(from, to) do
    from..to
    |> Task.async_stream(
      fn height ->
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
      end,
      max_concurrency: 6,
      timeout: 10_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce([], fn
      {:ok, nil}, acc -> acc
      {:ok, block}, acc -> [block | acc]
      {:exit, reason}, acc ->
        Logger.warning("BlockWarmer: fetch task exit: #{inspect(reason)}")
        acc
    end)
    |> Enum.reverse()
  end
end
