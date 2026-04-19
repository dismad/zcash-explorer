defmodule ZcashExplorer.Metrics.MempoolInfoWarmer do
  use Cachex.Warmer

  @doc """
  Returns the interval for this warmer.
  """
  def interval,
    do: :timer.seconds(3)

  @doc """
  Executes this cache warmer.
  """
  def execute(_state) do
    :ignore
  end

  
end
