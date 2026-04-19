defmodule ZcashExplorerWeb.TransactionHelper do
  @moduledoc """
  Central helper for determining Zcash transaction types.
  Works with both %Zcashex.Transaction{} structs and cache maps.
  """

  def tx_type(tx) when is_map(tx) do
    # If the cache already has a "type" key, use it
    case Map.get(tx, "type") do
      type when type in ["coinbase", "shielded", "shielding", "deshielding", "mixed", "transparent"] ->
        type
      _ ->
        calculate_type(tx)
    end
  end

  # Fallback for raw structs from Zcashex
  def tx_type(tx) do
    calculate_type(tx)
  end

  defp calculate_type(tx) do
    vin = Map.get(tx, :vin) || Map.get(tx, "vin") || []
    vout = Map.get(tx, :vout) || Map.get(tx, "vout") || []
    v_shielded_spend = Map.get(tx, :vShieldedSpend) || Map.get(tx, "vShieldedSpend") || []
    v_shielded_output = Map.get(tx, :vShieldedOutput) || Map.get(tx, "vShieldedOutput") || []

    cond do
      # Coinbase
      is_list(vin) && length(vin) > 0 && is_coinbase?(hd(vin)) ->
        "coinbase"

      # Fully shielded
      length(v_shielded_spend) > 0 && length(v_shielded_output) > 0 ->
        "shielded"

      # Shielding (t → z)
      length(v_shielded_output) > 0 && length(v_shielded_spend) == 0 ->
        "shielding"

      # Deshielding (z → t)
      length(v_shielded_spend) > 0 && length(v_shielded_output) == 0 ->
        "deshielding"

      # Mixed
      (length(vin) > 0 || length(vout) > 0) && (length(v_shielded_spend) > 0 || length(v_shielded_output) > 0) ->
        "mixed"

      # Transparent
      length(vin) > 0 || length(vout) > 0 ->
        "transparent"

      true ->
        "unknown"
    end
  end

  # Helper to safely check if first vin is coinbase
  defp is_coinbase?(vin) do
    Map.get(vin, :coinbase) != nil || Map.get(vin, "coinbase") != nil
  end
end