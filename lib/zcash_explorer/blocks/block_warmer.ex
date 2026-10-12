defmodule ZcashExplorer.Blocks.BlockWarmer do
  use Cachex.Warmer
  require Logger

  def interval, do: :timer.seconds(10)

  def execute(_state) do
    case ZcashExplorer.Blocks.Recent.list() do
      {:ok, blocks} ->
        {:ok, [{"block_cache", blocks}]}

      {:error, reason} ->
        Logger.error("Block warmer: #{inspect(reason)}")
        :ignore
    end
  end
end
