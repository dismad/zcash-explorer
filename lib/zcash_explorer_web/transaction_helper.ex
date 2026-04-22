defmodule ZcashExplorerWeb.TransactionHelper do
  import Phoenix.HTML

  def tx_type(tx) when is_map(tx) do
    pre_computed = Map.get(tx, "type") || Map.get(tx, :type)

    if pre_computed && pre_computed != "unknown" do
      badge(pre_computed)
    else
      badge(detect_type(tx))
    end
  end

  def tx_type(_), do: badge("unknown")

  defp detect_type(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []
    vout = Map.get(tx, "vout") || Map.get(tx, :vout) || []
    vjoinsplit = Map.get(tx, "vjoinsplit") || Map.get(tx, :vjoinsplit) || []
    orchard = Map.get(tx, "orchard") || Map.get(tx, :orchard)
    value_zat = Map.get(tx, "valueBalanceZat") || Map.get(tx, :valueBalanceZat) || 0
    orchard_zat = get_orchard_zat(orchard)

    is_coinbase = is_coinbase?(vin)
    has_transparent_out = length(vout) > 0

    cond do
      is_coinbase -> "coinbase"
      length(vjoinsplit) > 0 -> "sprout"
      # True deshielding only if we actually send to transparent
      (value_zat > 0 || orchard_zat > 0) && has_transparent_out -> "deshielding"
      # True shielding
      value_zat < 0 || orchard_zat < 0 -> "shielding"
      has_orchard?(orchard) -> "orchard"
      has_sapling?(tx) -> "sapling"
      length(vin) > 0 && length(vout) > 0 -> "transparent"
      true -> "mixed"
    end
  end

  defp get_orchard_zat(nil), do: 0

  defp get_orchard_zat(orchard) do
    Map.get(orchard, "valueBalanceZat") || Map.get(orchard, :valueBalanceZat) || 0
  end

  defp is_coinbase?(vin) when is_list(vin) do
    Enum.any?(vin, fn v -> Map.get(v, "coinbase") || Map.get(v, :coinbase) end)
  end

  defp is_coinbase?(_), do: false

  defp has_orchard?(nil), do: false

  defp has_orchard?(orchard) do
    actions = Map.get(orchard, "actions") || Map.get(orchard, :actions)
    is_list(actions) && length(actions) > 0
  end

  defp has_sapling?(tx) do
    (Map.get(tx, "vShieldedSpend") || Map.get(tx, :vShieldedSpend) || []) != [] ||
      (Map.get(tx, "vShieldedOutput") || Map.get(tx, :vShieldedOutput) || []) != []
  end

  defp badge(type) do
    case type do
      "coinbase" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-400 text-gray-900 capitalize">💰 Coinbase</span>}
        )

      "shielding" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-200 to-emerald-400 text-gray-900 capitalize">Shielding (T-Z)</span>}
        )

      "deshielding" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-emerald-400 to-amber-200 text-gray-900 capitalize">Deshielding (Z-T)</span>}
        )

      "orchard" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-400 text-gray-900 capitalize">🌳 Orchard</span>}
        )

      "sapling" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-400 text-gray-900 capitalize">🛡 Sapling</span>}
        )

      "sprout" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-400 text-gray-900 capitalize">🌱 Sprout</span>}
        )

      "transparent" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-200 text-gray-900 capitalize">🔍 Public</span>}
        )

      "mixed" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-200 text-gray-900 capitalize">Mixed</span>}
        )

      _ ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-200 text-gray-900">Unknown</span>}
        )
    end
  end
end