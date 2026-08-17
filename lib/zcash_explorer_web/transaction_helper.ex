defmodule ZcashExplorerWeb.TransactionHelper do
  import Phoenix.HTML

  @pure_shielded_pools ["ironwood", "orchard", "sapling", "sprout"]
  @priority_types ["coinbase", "shielding", "deshielding", "transparent"]

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

  # ---------------------------------------------------------------------------
  # ZSA badges (safe for both struct atom keys and raw RPC string keys)
  # ---------------------------------------------------------------------------

  def zsa_badges(nil), do: []

  def zsa_badges(tx) when is_map(tx) do
  summary = ZcashExplorer.ZsaDecoder.summarize(tx)

  []
  |> maybe_zsa_html(summary.is_v6, "V6", "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200")
  |> maybe_zsa_html(summary.likely_issuance, "Issuance", "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-200")
  |> maybe_zsa_html(
    truthy?(Map.get(tx, :burnexists) || Map.get(tx, "burnexists")),
    "Burn",
    "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200"
  )
  |> maybe_zsa_html(
    summary.likely_zsa or zsa_enabled?(tx),
    "ZSA",
    "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/40 dark:text-indigo-200"
  )
  |> Enum.reverse()
end


  defp maybe_zsa_html(list, true, label, classes) do
    [
      raw(
        ~s(<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium #{classes}">#{label}</span>)
      )
      | list
    ]
  end

  defp maybe_zsa_html(list, _, _, _), do: list

  defp zsa_enabled?(tx) when is_map(tx) do
    orchard = Map.get(tx, :orchard) || Map.get(tx, "orchard") || %{}
    flags = Map.get(orchard, :flags) || Map.get(orchard, "flags") || %{}
    truthy?(Map.get(flags, :enableZSA) || Map.get(flags, "enableZSA"))
  end

  defp zsa_enabled?(_), do: false

  defp truthy?(v), do: v in [true, "true", 1]

  # ---------------------------------------------------------------------------
  # Pools
  # ---------------------------------------------------------------------------

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

    if is_coinbase?(tx), do: List.delete(list, "transparent"), else: list
  end

  def pool_list(_), do: []

  def pool_badges(tx) when is_map(tx) do
    chips = Enum.map(pool_list(tx), &pool_badge/1)

    if turnstile?(tx) do
      chips ++ [pool_badge("turnstile")]
    else
      chips
    end
  end

  def pool_badges(_), do: []

  @doc "True when 2+ shielded pools are involved (Sapling/Orchard/Ironwood/Sprout)."
  def turnstile?(tx) when is_map(tx) do
    case Map.get(tx, "turnstile") do
      true ->
        true

      false ->
        false

      _ ->
        pools = Map.get(tx, "pools") || Map.get(tx, :pools) || pool_list(tx)
        shielded = Enum.count(pools, &(&1 in @pure_shielded_pools))
        shielded >= 2
    end
  end

  def turnstile?(_), do: false

  @doc "Largest absolute pool value-balance in zatoshis (turnstile size)."
  def turnstile_amount_zats(tx) when is_map(tx) do
    case Map.get(tx, "turnstile_zat") do
      n when is_integer(n) and n > 0 ->
        n

      n when is_float(n) and n > 0 ->
        round(n)

      _ ->
        if turnstile?(tx), do: max_pool_abs_zat(tx), else: 0
    end
  end

  def turnstile_amount_zats(_), do: 0

  def turnstile_amount_zec(tx) do
    turnstile_amount_zats(tx) / 100_000_000.0
  end

  def pool_flow_zec(tx) when is_map(tx) do
    %{
      sapling: sapling_zat(tx) / 100_000_000.0,
      orchard: get_pool_zat(pool_field(tx, :orchard)) / 100_000_000.0,
      ironwood: get_pool_zat(pool_field(tx, :ironwood)) / 100_000_000.0,
      turnstile: turnstile_amount_zec(tx)
    }
  end

  def pool_flow_zec(_), do: %{sapling: 0.0, orchard: 0.0, ironwood: 0.0, turnstile: 0.0}

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
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-yellow-400 text-gray-900 dark:bg-yellow-500 dark:text-gray-900">Sapling</span>}
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

  def pool_badge("turnstile") do
    raw(
      ~S{<span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-violet-100 text-violet-800 dark:bg-violet-900/40 dark:text-violet-200">Turnstile</span>}
    )
  end

  def pool_badge(_), do: raw("")

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp detect_type(tx) do
    vin = Map.get(tx, "vin") || Map.get(tx, :vin) || []
    vout = Map.get(tx, "vout") || Map.get(tx, :vout) || []
    vjoinsplit = Map.get(tx, "vjoinsplit") || Map.get(tx, :vjoinsplit) || []
    orchard = pool_field(tx, :orchard)
    ironwood = pool_field(tx, :ironwood)

    value_zat = sapling_zat(tx)
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

      has_t_in and has_z and (not has_t_out or into_shielded?) ->
        "shielding"

      has_z and has_t_out and (not has_t_in or out_of_shielded?) ->
        "deshielding"

      has_z and not has_t_in and not has_t_out ->
        "shielded"

      has_t_in and has_t_out and not has_z ->
        "transparent"

      has_t_in and has_t_out and has_z ->
        cond do
          into_shielded? -> "shielding"
          out_of_shielded? -> "deshielding"
          true -> "mixed"
        end

      true ->
        "mixed"
    end
  end

  defp max_pool_abs_zat(tx) do
    [
      abs(sapling_zat(tx)),
      abs(get_pool_zat(pool_field(tx, :orchard))),
      abs(get_pool_zat(pool_field(tx, :ironwood)))
    ]
    |> Enum.max()
  end

  defp sapling_zat(tx) do
    Map.get(tx, "valueBalanceZat") || Map.get(tx, :valueBalanceZat) || 0
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
