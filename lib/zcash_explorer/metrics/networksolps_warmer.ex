defmodule ZcashExplorer.Metrics.NetworkSolpsWarmer do
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
    case safe_getnetworksolps(60_000) do
      {:ok, info} ->
        handle_result({:ok, info})

      {:error, reason} ->
        Logger.warning("NetworkSolpsWarmer: #{inspect(reason)}")
        :ignore
    end
  end

  defp safe_getnetworksolps(timeout) do
    try do
      # Matches earlier timeout stack: getnetworksolps with [120, -1]
      case GenServer.call(Zcashex, {:call_endpoint, "getnetworksolps", [120, -1]}, timeout) do
        {:ok, info} -> {:ok, info}
        other -> {:error, other}
      end
    catch
      :exit, reason -> {:error, reason}
    end
  end

  defp handle_result({:ok, info}) do
    {:ok, [{"networksolps", info}]}
  end
end
