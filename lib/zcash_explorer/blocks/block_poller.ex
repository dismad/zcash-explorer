defmodule ZcashExplorer.Blocks.BlockPoller do
  use GenServer
  require Logger

  @max_blocks 200
  @interval 2_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{last_height: -1, blocks: []}, name: __MODULE__)
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

  defp poll(%{last_height: last_height, blocks: existing} = state) do
    Logger.info("BlockPoller: cycle started")

    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) ->
        new_blocks =
          cond do
            last_height < 0 ->
              start_height = max(0, tip - 50)
              Logger.info("BlockPoller: first run, fetching #{start_height}..#{tip}")
              fetch_range(start_height, tip)

            last_height < tip ->
              from = last_height + 1
              Logger.info("BlockPoller: fetching new blocks #{from}..#{tip}")
              fetch_range(from, tip)

            true ->
              Logger.info("BlockPoller: tip unchanged (#{tip})")
              []
          end

        updated =
          (existing ++ new_blocks)
          |> Enum.uniq_by(& &1["height"])
          |> Enum.sort_by(& &1["height"], :desc)
          |> Enum.take(@max_blocks)

        Cachex.put(:app_cache, "block_cache", updated)
        Logger.info("BlockPoller: wrote #{length(updated)} blocks (tip #{tip})")
        %{last_height: tip, blocks: updated}

      {:error, reason} ->
        Logger.error("BlockPoller: getblockcount failed: #{inspect(reason)}")
        state

      other ->
        Logger.warning("BlockPoller: unexpected getblockcount: #{inspect(other)}")
        state
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
            Logger.warning("BlockPoller: getblock #{height} failed: #{inspect(other)}")
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
        Logger.warning("BlockPoller: fetch task exit: #{inspect(reason)}")
        acc
    end)
    |> Enum.reverse()
  end
end
