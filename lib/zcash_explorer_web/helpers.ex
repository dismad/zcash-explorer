defmodule ZcashExplorerWeb.Helpers do
  # Simple implementations to get the app starting
  def mined_time(timestamp) when is_integer(timestamp) do
    Timex.from_unix(timestamp) |> Timex.format!("{ISO:Extended}")
  end

  def mined_time_rel(timestamp) when is_integer(timestamp) do
    Timex.from_unix(timestamp) |> Timex.format!("{relative}", :relative)
  end

  def output_total(tx_list) when is_list(tx_list) do
    Enum.reduce(tx_list, 0, fn tx, acc ->
      vout = Map.get(tx, :vout) || Map.get(tx, "vout") || []
      Enum.reduce(vout, acc, fn vout_tx, sum ->
        value = Map.get(vout_tx, :value) || Map.get(vout_tx, "value") || 0
        sum + value
      end)
    end)
  end

  def tx_out_total(tx) do
    vout = Map.get(tx, :vout) || Map.get(tx, "vout") || []
    Enum.reduce(vout, 0, fn vout_tx, sum ->
      value = Map.get(vout_tx, :value) || Map.get(vout_tx, "value") || 0
      sum + value
    end)
  end

  def tx_type(_tx) do
    "unknown"
  end

  def zatoshi_to_zec(zat) do
    Decimal.div(Decimal.new(zat || 0), Decimal.new(100_000_000))
    |> Decimal.to_string()
  end

 def get_network(assigns) do
    assigns[:zcash_network] || "mainnet"
  end

  def conn_or_socket(conn, socket) do
    conn || (socket && socket.assigns[:conn]) || %{}
  end

end

