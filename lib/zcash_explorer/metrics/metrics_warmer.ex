defmodule ZcashExplorer.Metrics.MetricsWarmer do
  use Cachex.Warmer
  require Logger

  @doc """
  Returns the interval for this warmer.
  """
  def interval, do: :timer.seconds(15)

  @doc """
  Executes this cache warmer.
  """
  def execute(_state) do
    case safe_getblockchaininfo(60_000) do
      {:ok, info} ->
        handle_result({:ok, info})

      {:error, reason} ->
        Logger.warning("MetricsWarmer: #{inspect(reason)}")
        :ignore
    end
  end

  defp safe_getblockchaininfo(timeout) do
    try do
      case GenServer.call(Zcashex, {:call_endpoint, :getblockchaininfo}, timeout) do
        {:ok, info} -> {:ok, info}
        other -> {:error, other}
      end
    catch
      :exit, reason -> {:error, reason}
    end
  end

  defp handle_result({:ok, info}) do
    {:ok, [{"metrics", info}]}
  end
end
