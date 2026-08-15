defmodule ZcashExplorer.Crosslink do
  @moduledoc """
  Thin wrappers around zebra-crosslink TFL / staking RPCs.
  """

  @default_timeout 12_000

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

  def staking_positions do
    call("wallet_staking_positions", [], 15_000)
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

  # --- helpers ---

   # JSON returns hash as a list of 32 integers (internal byte order).
  # Reverse before hex-encoding so it matches getblock / explorer URLs.
  defp normalize_hash(bytes) when is_list(bytes) and length(bytes) == 32 do
    bytes
    |> Enum.reverse()
    |> :binary.list_to_bin()
    |> Base.encode16(case: :lower)
  end

  defp normalize_hash(hash) when is_binary(hash) do
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

  defp normalize_hash(_), do: nil
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