defmodule ZcashExplorerWeb.TransactionHelper do
  @moduledoc """
  Accurate Zcash transaction type classification.
  Shielding and deshielding have strict priority.
  """

  def tx_type(tx) when is_map(tx) do
    calculate_type(tx)
  end

  defp calculate_type(tx) do
    vin = get_field(tx, :vin) || get_field(tx, "vin") || []
    vout = get_field(tx, :vout) || get_field(tx, "vout") || []
    shielded_spend = get_field(tx, :vShieldedSpend) || get_field(tx, "vShieldedSpend") || []
    shielded_output = get_field(tx, :vShieldedOutput) || get_field(tx, "vShieldedOutput") || []
    joinsplit = get_field(tx, :vjoinsplit) || get_field(tx, "vjoinsplit") || []
    orchard = get_field(tx, :orchard) || get_field(tx, "orchard") || %{}

    cond do
      # 1. Coinbase
      is_coinbase?(vin) ->
        "coinbase"

      # 2. Shielding (T → Z)
      length(vin) > 0 and length(shielded_output) > 0 ->
        "shielding"

      # 3. Deshielding (Z → T) - relaxed condition (vin can be > 0)
      length(shielded_spend) > 0 and length(vout) > 0 ->
        "deshielding"

      # 4. Mixed
      length(vin) > 0 and length(vout) > 0 and (length(shielded_spend) > 0 or length(shielded_output) > 0) ->
        "mixed"

      # 5. Fully shielded Sapling
      length(shielded_spend) > 0 and length(shielded_output) > 0 and length(vin) == 0 and length(vout) == 0 ->
        "sapling"

      # 6. Sprout
      length(joinsplit) > 0 ->
        "sprout"

      # 7. Pure Orchard
      has_orchard_activity?(orchard) and length(shielded_spend) == 0 and length(shielded_output) == 0 ->
        "orchard"

      # 8. Regular transparent
      length(vin) > 0 and length(vout) > 0 ->
        "transparent"

      true ->
        "unknown"
    end
  end

  defp has_orchard_activity?(orchard) when is_map(orchard) do
    value = get_field(orchard, :valueBalance) || get_field(orchard, "valueBalance")
    actions = get_field(orchard, :actions) || get_field(orchard, "actions")
    (value != nil and value != 0) or (actions != nil and length(actions) > 0)
  end
  defp has_orchard_activity?(_), do: false

  defp is_coinbase?(vin_list) when is_list(vin_list) and length(vin_list) > 0 do
    first = hd(vin_list)
    get_field(first, :coinbase) != nil or get_field(first, "coinbase") != nil
  end
  defp is_coinbase?(_), do: false

  defp get_field(data, key) when is_struct(data), do: Map.get(data, key)
  defp get_field(data, key) when is_map(data), do: Map.get(data, key) || Map.get(data, to_string(key))
  defp get_field(_, _), do: nil
end