defmodule ZcashExplorer.Blocks.Recent do
  @moduledoc """
  The recent-blocks list, fetched from the node on demand.

  Always asks for the current tip and the last `@window` heights at verbosity 1,
  in parallel. No cache merge: a successful call is the tip, a failed call is
  `{:error, _}` so the caller can keep what it already showed.
  """

  require Logger

  @window 60
  @timeout 8_000

  def list do
    case Zcashex.getblockcount() do
      {:ok, tip} when is_integer(tip) and tip >= 0 ->
        from = max(tip - @window + 1, 0)

        blocks =
          from..tip
          |> Task.async_stream(&fetch/1, max_concurrency: 8, timeout: @timeout, on_timeout: :kill_task)
          |> Enum.flat_map(fn
            {:ok, block} when is_map(block) -> [block]
            _ -> []
          end)
          |> Enum.sort(&(&1["height"] >= &2["height"]))

        case blocks do
          [%{"height" => h} | _] = list when h == tip -> {:ok, list}
          [%{"height" => h} | _] = list ->
            Logger.warning("Recent blocks: tip #{tip}, newest fetched #{h}")
            {:ok, list}
          [] ->
            {:error, :empty}
        end

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, other}
    end
  end

  defp fetch(height) do
    case Zcashex.getblock(Integer.to_string(height), 1) do
      {:ok, block} when is_map(block) ->
        %{
          "height" => block["height"],
          "size" => block["size"],
          "hash" => block["hash"],
          "time" => ZcashExplorerWeb.Helpers.mined_time(block["time"]),
          "tx_count" => block["nTx"] || length(block["tx"] || []),
          "output_total" => nil
        }

      _ ->
        nil
    end
  end
end
