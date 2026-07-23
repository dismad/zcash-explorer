defmodule ZcashExplorerWeb.TransactionHelper do
  import Phoenix.HTML

  @pure_shielded_pools ["ironwood", "orchard", "sapling", "sprout"]
  @priority_types ["coinbase", "shielding", "deshielding", "transparent"]

  @doc """
  Returns a string type name for warmers and lists.
  Never returns HTML.
  """
  def classify(tx) when is_map(tx) do
    pools = Map.get(tx, "pools") || Map.get(tx, :pools) || pool_list(tx)
    has_shielded_pool? = Enum.any?(pools, &(&1 in @pure_shielded_pools))
    has_transparent? = "transparent" in pools

    pre = Map.get(tx, "type") || Map.get(tx, :type)
    pre = if is_binary(pre), do: pre, else: nil

    detected = detect_type(tx)

    cond do
      detected in @priority_types ->
        detected

      is_binary(pre) and pre in @priority_types ->
        pre

      Map.get(tx, "is_coinbase") == true or Map.get(tx, :is_coinbase) == true ->
        "coinbase"

      has_shielded_pool? and not has_transparent? ->
        "shielded"

      is_binary(pre) and pre in @pure_shielded_pools ->
        "shielded"

      detected == "shielded" ->
        "shielded"

      is_binary(pre) and pre not in ["unknown", "mixed", ""] ->
        pre

      true ->
        detected
    end
  end

  def classify(_), do: "unknown"

  def tx_type(tx) when is_map(tx), do: badge(classify(tx))
  def tx_type(_), do: badge("unknown")

  def pool_list(tx) when is_map(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []
    vjoinsplit = Map.get(tx, "vjoinsplit") || Map.get(tx, :vjoinsplit) || []

    has_transparent =
      length(vin) > 0 or
        length(Map.get(tx, "vout") || Map.get(tx, :vout) || []) > 0

    has_sprout = is_list(vjoinsplit) and vjoinsplit != []
    has_sapling = has_sapling?(tx)

    orchard = pool_field(tx, :orchard)
    has_orchard = has_pool?(orchard)

    ironwood = pool_field(tx, :ironwood)
    has_ironwood = has_pool?(ironwood)

    list =
      []
      |> then(fn l -> if has_transparent, do: ["transparent" | l], else: l end)
      |> then(fn l -> if has_sprout, do: ["sprout" | l], else: l end)
      |> then(fn l -> if has_sapling, do: ["sapling" | l], else: l end)
      |> then(fn l -> if has_orchard, do: ["orchard" | l], else: l end)
      |> then(fn l -> if has_ironwood, do: ["ironwood" | l], else: l end)
      |> Enum.reverse()

    if is_coinbase?(tx) do
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
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200">Transparent</span>}
    )
  end

  def pool_badge("sprout") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-purple-50 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300">Sprout</span>}
    )
  end

  def pool_badge("sapling") do
  raw(
    ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-yellow-100 text-yellow-900 dark:bg-yellow-900/40 dark:text-yellow-200">Sapling</span>}
  )
end

  def pool_badge("orchard") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-emerald-50 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300">Orchard</span>}
    )
  end

  def pool_badge("ironwood") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-orange-50 text-orange-700 dark:bg-orange-900/40 dark:text-orange-300">Ironwood</span>}
    )
  end

  def pool_badge(_), do: raw("")

 defp detect_type(tx) do
  vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []
  vout = Map.get(tx, "vout") || Map.get(tx, :vout) || []
  vjoinsplit = Map.get(tx, "vjoinsplit") || Map.get(tx, :vjoinsplit) || []
  orchard = pool_field(tx, :orchard)
  ironwood = pool_field(tx, :ironwood)

  value_zat = Map.get(tx, "valueBalanceZat") || Map.get(tx, :valueBalanceZat) || 0
  orchard_zat = get_pool_zat(orchard)
  ironwood_zat = get_pool_zat(ironwood)

  pools = Map.get(tx, "pools") || Map.get(tx, :pools) || []
  stored = Map.get(tx, "type") || Map.get(tx, :type)
  stored = if is_binary(stored), do: stored, else: nil

  coinbase? = is_coinbase?(tx) or stored == "coinbase"
  has_t_in = not coinbase? and length(vin) > 0
  has_t_out = length(vout) > 0

  has_z =
    has_pool?(ironwood) or has_pool?(orchard) or has_sapling?(tx) or
      (is_list(vjoinsplit) and vjoinsplit != []) or
      Enum.any?(pools, &(&1 in @pure_shielded_pools))

  into_shielded? = value_zat < 0 or orchard_zat < 0 or ironwood_zat < 0
  out_of_shielded? = value_zat > 0 or orchard_zat > 0 or ironwood_zat > 0

  cond do
    coinbase? ->
      "coinbase"

    stored in ["shielding", "deshielding", "transparent", "shielded"] ->
      stored

    # Transparent → shielded (any pool, including Ironwood)
    has_t_in and has_z and (not has_t_out or into_shielded?) ->
      "shielding"

    # Shielded → transparent
    has_z and has_t_out and (not has_t_in or out_of_shielded?) ->
      "deshielding"

    # Pure shielded or cross-pool (Ironwood ↔ Sapling, etc.)
    has_z and not has_t_in and not has_t_out ->
      "shielded"

    has_t_in and has_t_out and not has_z ->
      "transparent"

    has_t_in and has_t_out and has_z ->
      # both sides present without clear balance sign
      if into_shielded?, do: "shielding", else: if(out_of_shielded?, do: "deshielding", else: "mixed")

    true ->
      "mixed"
  end
end

  defp pool_field(tx, key) when is_atom(key) do
    Map.get(tx, key) || Map.get(tx, Atom.to_string(key))
  end

  defp get_pool_zat(nil), do: 0

  defp get_pool_zat(pool) when is_map(pool) do
    Map.get(pool, "valueBalanceZat") || Map.get(pool, :valueBalanceZat) || 0
  end

  defp get_pool_zat(_), do: 0

  defp is_coinbase?(tx) when is_map(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []

    Enum.any?(vin, fn v ->
      is_map(v) and (Map.get(v, "coinbase") != nil or Map.get(v, :coinbase) != nil)
    end) or
      Map.get(tx, "is_coinbase") == true or
      Map.get(tx, :is_coinbase) == true
  end

  defp is_coinbase?(_), do: false

  defp has_pool?(nil), do: false

  defp has_pool?(pool) when is_map(pool) do
    actions = Map.get(pool, "actions") || Map.get(pool, :actions) || []
    n_actions = Map.get(pool, "nActions") || Map.get(pool, :nActions) || 0
    zat = Map.get(pool, "valueBalanceZat") || Map.get(pool, :valueBalanceZat)

    (is_list(actions) and actions != []) or
      (is_integer(n_actions) and n_actions > 0) or
      (is_integer(zat) and zat != 0)
  end

  defp has_pool?(_), do: false

  defp has_sapling?(tx) do
    (Map.get(tx, "vShieldedSpend") || Map.get(tx, :vShieldedSpend) || []) != [] or
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
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-200 to-emerald-400 text-gray-900 capitalize">Shielding</span>}
        )

      "deshielding" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-emerald-400 to-amber-200 text-gray-900 capitalize">Deshielding</span>}
        )

      "shielded" ->
        raw(
          ~S{<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-400 text-gray-900 capitalize">Shielded</span>}
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
