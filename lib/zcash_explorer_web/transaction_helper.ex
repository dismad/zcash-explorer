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

  def pool_list(tx) when is_map(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []

    has_transparent =
      length(vin) > 0 or
        length(Map.get(tx, "vout") || Map.get(tx, :vout) || []) > 0

    has_sapling = has_sapling?(tx)

    orchard = Map.get(tx, "orchard") || Map.get(tx, :orchard)
    has_orchard = has_pool?(orchard)

    ironwood = Map.get(tx, "ironwood") || Map.get(tx, :ironwood)
    has_ironwood = has_pool?(ironwood)

    list =
      []
      |> then(fn l -> if has_transparent, do: ["transparent" | l], else: l end)
      |> then(fn l -> if has_sapling, do: ["sapling" | l], else: l end)
      |> then(fn l -> if has_orchard, do: ["orchard" | l], else: l end)
      |> then(fn l -> if has_ironwood, do: ["ironwood" | l], else: l end)
      |> Enum.reverse()

    # Coinbase always has transparent outputs — hide the redundant chip
    if is_coinbase?(vin) do
      List.delete(list, "transparent")
    else
      list
    end
  end

  def pool_list(_), do: []

  def pool_badges(tx) when is_map(tx) do
    Enum.map(pool_list(tx), &pool_badge/1)
  end

  def pool_badges(_), do: []

  def pool_badge("transparent") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-red-50 text-red-700 dark:bg-red-900/40 dark:text-red-300">Transparent</span>}
    )
  end

  def pool_badge("sapling") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-yellow-50 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300">Sapling</span>}
    )
  end

  def pool_badge("orchard") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-emerald-50 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300">Orchard</span>}
    )
  end

  def pool_badge("ironwood") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-teal-50 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300">Ironwood</span>}
    )
  end

  def pool_badge(_), do: raw("")

  defp detect_type(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []
    vout = Map.get(tx, "vout") || Map.get(tx, :vout) || []
    vjoinsplit = Map.get(tx, "vjoinsplit") || Map.get(tx, :vjoinsplit) || []
    orchard = Map.get(tx, "orchard") || Map.get(tx, :orchard)
    ironwood = Map.get(tx, "ironwood") || Map.get(tx, :ironwood)

    value_zat = Map.get(tx, "valueBalanceZat") || Map.get(tx, :valueBalanceZat) || 0
    orchard_zat = get_pool_zat(orchard)
    ironwood_zat = get_pool_zat(ironwood)

    is_coinbase = is_coinbase?(vin)
    has_transparent_out = length(vout) > 0

    cond do
      is_coinbase ->
        "coinbase"

      length(vjoinsplit) > 0 ->
        "sprout"

      (value_zat > 0 || orchard_zat > 0 || ironwood_zat > 0) && has_transparent_out ->
        "deshielding"

      value_zat < 0 || orchard_zat < 0 || ironwood_zat < 0 ->
        "shielding"

      has_pool?(ironwood) ->
        "ironwood"

      has_pool?(orchard) ->
        "orchard"

      has_sapling?(tx) ->
        "sapling"

      length(vin) > 0 && length(vout) > 0 ->
        "transparent"

      true ->
        "mixed"
    end
  end

  defp get_pool_zat(nil), do: 0

  defp get_pool_zat(pool) do
    Map.get(pool, "valueBalanceZat") || Map.get(pool, :valueBalanceZat) || 0
  end

  defp is_coinbase?(vin) when is_list(vin) do
    Enum.any?(vin, fn v -> Map.get(v, "coinbase") || Map.get(v, :coinbase) end)
  end

  defp is_coinbase?(_), do: false

  defp has_pool?(nil), do: false

  defp has_pool?(pool) do
    actions = Map.get(pool, "actions") || Map.get(pool, :actions)
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
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-400 text-gray-900 capitalize">Coinbase</span>}
        )

      "shielding" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-200 to-emerald-400 text-gray-900 capitalize">Shielding (T-Z)</span>}
        )

      "deshielding" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-emerald-400 to-amber-200 text-gray-900 capitalize">Deshielding (Z-T)</span>}
        )

      "ironwood" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-teal-500 text-gray-900 capitalize">Ironwood</span>}
        )

      "orchard" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-400 text-gray-900 capitalize">Orchard</span>}
        )

      "sapling" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-400 text-gray-900 capitalize">Sapling</span>}
        )

      "sprout" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-400 text-gray-900 capitalize">Sprout</span>}
        )

      "transparent" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-200 text-gray-900 capitalize">Public</span>}
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