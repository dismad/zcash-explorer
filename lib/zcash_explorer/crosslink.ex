defmodule ZcashExplorer.Crosslink do
  @moduledoc """
  Thin wrappers around zebra-crosslink TFL / staking RPCs.

  Constants match ShieldedLabs/crosslink_monolith v14
  (`librustzcash` `STAKING_PERIOD`, `STAKING_DAY_WINDOW`, `ACTIVE_ROSTER_MAX_N`).
  Commission split is the v14 feature-net issuance rule: 10% of PoS rewards
  to active finalizers by weight, 90% to staking bonds.
  """

  @default_timeout 12_000

  # v14 feature-net parameters. Block target on the feature net makes the
  # window ~1 day and the period ~3 days; the chain counts blocks, not wall time.
  @staking_period 10_368
  @staking_day_window 3_456
  @active_roster_max 12
  @commission_bps 1_000

  def staking_params do
    %{
      period: @staking_period,
      day_window: @staking_day_window,
      active_roster_max: @active_roster_max,
      commission_bps: @commission_bps
    }
  end

  def is_activated do
    case call("is_tfl_activated") do
      {:ok, true} -> true
      {:ok, false} -> false
      _ -> :unknown
    end
  end

  def finalized_tip do
    case call("get_tfl_final_block_height_and_hash") do
      {:ok, result} when is_map(result) ->
        {:ok,
         %{
           height: result["height"] || result["block_height"],
           hash: normalize_hash(result["hash"] || result["block_hash"])
         }}

      other ->
        other
    end
  end

  def recency_status do
    call("get_tfl_recency_status", [], 15_000)
  end

  def block_finality(hash) when is_binary(hash) do
    call("get_tfl_block_finality_from_hash", [hash])
  end

  def tx_finality(txid) when is_binary(txid) do
    call("get_tfl_tx_finality_from_hash", [txid])
  end

  def roster(unit \\ :zec) do
    method = if unit == :zats, do: "get_tfl_roster_zats", else: "get_tfl_roster_zec"
    call(method, [], 15_000)
  end

  # Same as roster(:zats), but finalizer_address is the zfinv1 string when the node knows it.
  # Falls back to the plain roster on a node that does not have this method yet.
  def roster_with_addresses do
    case call("get_tfl_roster_with_addresses", [], 15_000) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> roster(:zats)
    end
  end

  # Reward bank in zats. Key is the raw 32-byte finalizer pubkey, same bytes as the roster.
  def reward_balance(raw_hex) when is_binary(raw_hex) do
    case call("getfinalizerrewardbalance", [raw_hex]) do
      {:ok, n} when is_integer(n) -> n
      {:ok, n} when is_float(n) -> trunc(n)
      _ -> 0
    end
  end

  def fat_pointer do
    call("get_tfl_fat_pointer_to_bft_chain_tip", [], 15_000)
  end

  def bond_info(bond_key) when is_binary(bond_key) do
    call("getbondinfo", [bond_key])
  end

  def block_subsidy(height \\ nil) do
    params = if is_integer(height), do: [height], else: []
    call("getblocksubsidy", params)
  end

  def staking_positions do
    call("wallet_staking_positions", [], 15_000)
  end

  def wallet_ufvk do
    call("get_wallet_ufvk", [], 15_000)
  end

  def spendable_funds do
    call("wallet_spendable_funds", [], 15_000)
  end

  def staking_totals do
    case staking_positions() do
      {:ok, %{"active" => active, "withdrawable" => withdrawable}} ->
        bonded =
          active
          |> Map.values()
          |> List.flatten()
          |> Enum.reduce(0, fn pos, acc ->
            acc + (pos["latest_val"] || 0)
          end)

        unbonded =
          (withdrawable || [])
          |> Enum.reduce(0, fn pos, acc ->
            acc + (pos["latest_val"] || pos["value"] || 0)
          end)

        {:ok, %{bonded_zat: bonded, unbonded_zat: unbonded}}

      {:ok, _} ->
        {:ok, %{bonded_zat: 0, unbonded_zat: 0}}

      other ->
        other
    end
  end

  def bondinfo(bond_key) when is_binary(bond_key) do
    reversed = reverse_pk(bond_key)
    call("getbondinfo", [reversed])
  end

  def blockchain_info do
    call("getblockchaininfo", [], 15_000)
  end

  def value_pools do
    case blockchain_info() do
      {:ok, %{"valuePools" => pools}} when is_list(pools) -> {:ok, pools}
      other -> other
    end
  end

  def orchard_pool do
    case value_pools() do
      {:ok, pools} ->
        pool = Enum.find(pools, &(&1["id"] == "orchard"))
        {:ok, pool}

      other ->
        other
    end
  end

  def finalizer_count do
    case recency_status() do
      {:ok, %{"finalizer_statuses" => list}} when is_list(list) -> {:ok, length(list)}
      _ -> {:ok, 0}
    end
  end

  def pos_height do
    case recency_status() do
      {:ok, %{"my_height" => h}} when is_integer(h) -> {:ok, h}
      _ -> {:ok, nil}
    end
  end

  # JSON returns block hashes as a list of 32 integers (internal byte order).
  # Reverse before hex-encoding so it matches getblock / explorer URLs.
  def normalize_hash(bytes) when is_list(bytes) and length(bytes) == 32 do
    bytes
    |> Enum.reverse()
    |> :binary.list_to_bin()
    |> Base.encode16(case: :lower)
  end

  def normalize_hash(hash) when is_binary(hash) do
    cond do
      Regex.match?(~r/^[0-9a-fA-F]{64}$/, hash) ->
        String.downcase(hash)

      byte_size(hash) == 32 ->
        hash
        |> :binary.bin_to_list()
        |> Enum.reverse()
        |> :binary.list_to_bin()
        |> Base.encode16(case: :lower)

      true ->
        nil
    end
  end

  def normalize_hash(_), do: nil

  # Roster RPCs hex-encode the raw 32-byte key (`serde` hex). Recency and
  # wallet positions use `PubKeyID`, which reverses those bytes before hex.
  # Return both so callers can join the two shapes.
  def pubkey_forms(hex) when is_binary(hex) do
    cleaned =
      hex
      |> String.replace(~r/^0x/i, "")
      |> String.downcase()

    if Regex.match?(~r/^[0-9a-f]{64}$/, cleaned) do
      reversed = reverse_pk(cleaned)
      %{raw: cleaned, display: reversed}
    else
      %{raw: cleaned, display: cleaned}
    end
  end

  def pubkey_forms(_), do: %{raw: nil, display: nil}

  @zfinv_prefix "zfinv1"

  # zfinv1 is 32-byte raw pubkey then 64-byte signature, base64url, no padding.
  # The roster display key is that pubkey reversed (PubKeyID). Return both.
  def decode_finalizer_address(@zfinv_prefix <> rest) when byte_size(rest) == 128 do
    case Base.url_decode64(rest, padding: false) do
      {:ok, <<pk::binary-size(32), _sig::binary-size(64)>>} ->
        raw = Base.encode16(pk, case: :lower)
        %{raw: raw, display: reverse_pk(raw)}

      _ ->
        nil
    end
  end

  def decode_finalizer_address(_), do: nil

  defp call(method, params \\ [], timeout \\ @default_timeout) do
    try do
      GenServer.call(Zcashex, {:call_endpoint, method, params}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, reason}
    end
  end

  defp reverse_pk(hex) when is_binary(hex) do
    hex
    |> String.replace(~r/^0x/i, "")
    |> Base.decode16!(case: :mixed)
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> :binary.list_to_bin()
    |> Base.encode16(case: :lower)
  end
end
