defmodule ZcashExplorer.ZsaDecoder do
  @moduledoc """
  Best-effort decoder for V6 / ZSA transaction hex.

  Distinguishes:
    - V6 transactions
    - General ZSA activity (transfers / large shielded payloads)
    - Issuance (IssueAction-shaped records + issuance-like tail)

  Used when the node does not expose issuanceexists / getassetstate.
  """

  use Bitwise

  def summarize(nil), do: empty()
  def summarize(""), do: empty()

  def summarize(hex) when is_binary(hex) do
    with {:ok, bin} <- decode_hex(hex),
         {:ok, meta, rest} <- parse_prefix(bin) do
      hashes = extract_from_rest(rest)
      size = byte_size(bin)

      is_v6 = meta.version == 6
      # ZSA activity: V6 with non-trivial shielded payload
      likely_zsa = is_v6 and size > 500
      # Issuance: only with strong IssueAction candidate + issuance-shaped tail
      likely_issuance = is_v6 and hashes != [] and issuance_shaped?(bin)

      %{
        version: meta.version,
        version_group_id: meta.version_group_id,
        is_v6: is_v6,
        likely_zsa: likely_zsa,
        likely_issuance: likely_issuance,
        asset_desc_hashes: if(likely_issuance, do: hashes, else: []),
        note_count: nil
      }
    else
      _ -> empty()
    end
  end

  def summarize(%{"hex" => hex}), do: summarize(hex)
  def summarize(%{hex: hex}), do: summarize(hex)
  def summarize(_), do: empty()

  defp empty do
    %{
      version: nil,
      version_group_id: nil,
      is_v6: false,
      likely_zsa: false,
      likely_issuance: false,
      asset_desc_hashes: [],
      note_count: nil
    }
  end

  defp decode_hex(hex) do
    hex = String.replace(hex, ~r/[^0-9a-fA-F]/, "")

    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, :bad_hex}
    end
  end

  # ---------------------------------------------------------------------------
  # Prefix: version | versionGroupId | consensusBranchId | lockTime | expiry
  #         | vin_count | vout_count
  # ---------------------------------------------------------------------------

  defp parse_prefix(
         <<ver_le::little-32, vgid_le::little-32, _branch::little-32, _lock::little-32,
           _expiry::little-32, rest::binary>>
       ) do
    version = band(ver_le, 0x7FFFFFFF)

    case rest do
      # empty transparent in/out
      <<0, 0, rest2::binary>> ->
        {:ok, %{version: version, version_group_id: vgid_le}, rest2}

      <<0, rest2::binary>> ->
        {:ok, %{version: version, version_group_id: vgid_le}, rest2}

      _ ->
        {:ok, %{version: version, version_group_id: vgid_le}, rest}
    end
  end

  defp parse_prefix(_), do: {:error, :short}

  # ---------------------------------------------------------------------------
  # Search remaining bytes for IssueAction-shaped records
  # ---------------------------------------------------------------------------

  defp extract_from_rest(bin) when byte_size(bin) < 40, do: []

  defp extract_from_rest(bin) do
    size = byte_size(bin)
    # Prefer the last 40% — issuance sits after orchard proofs
    start_at = div(size * 3, 5)

    do_scan(bin, start_at, size, [])
    |> Enum.reverse()
    |> Enum.uniq()
    |> case do
      [] -> []
      list -> [List.last(list)]
    end
  end

  defp do_scan(_bin, offset, size, acc) when offset + 40 > size, do: acc

  defp do_scan(bin, offset, size, acc) do
    case match_issue_action_at(bin, offset) do
      {:ok, hash, step} ->
        do_scan(bin, offset + step, size, [hash | acc])

      :no ->
        do_scan(bin, offset + 1, size, acc)
    end
  end

  defp match_issue_action_at(bin, offset) do
    rest_size = byte_size(bin) - offset

    if rest_size < 40 do
      :no
    else
      do_match(bin, offset, rest_size)
    end
  end

  defp do_match(bin, offset, rest_size) do
    hash = binary_part(bin, offset, 32)
    after_hash = binary_part(bin, offset + 32, rest_size - 32)

    case read_compact_size(after_hash) do
      # Typical single-asset test issuance: nNotes = 1
      {:ok, 1, cs_len} ->
        available = rest_size - 32 - cs_len

        if available >= 81 and strong_hash?(hash) do
          {:ok, Base.encode16(hash, case: :lower), 32 + cs_len + 81}
        else
          :no
        end

      # Allow up to 4 notes for multi-output issuances
      {:ok, n, cs_len} when n in 2..4 ->
        available = rest_size - 32 - cs_len
        need = n * 80 + 1

        if available >= need and strong_hash?(hash) do
          {:ok, Base.encode16(hash, case: :lower), 32 + cs_len + need}
        else
          :no
        end

      _ ->
        :no
    end
  end

  defp strong_hash?(<<0::256>>), do: false
  defp strong_hash?(<<0xFF::256>>), do: false

  defp strong_hash?(hash) do
    bytes = :binary.bin_to_list(hash)
    uniq = length(Enum.uniq(bytes))
    zeros = Enum.count(bytes, &(&1 == 0))
    uniq >= 16 and zeros <= 4
  end

  # Rough issuance tail check: look for a 64/65-byte signature-sized trailer
  # (issueAuthSig). Ordinary transfers usually don't end this way.
  defp issuance_shaped?(bin) when byte_size(bin) < 80, do: false

  defp issuance_shaped?(bin) do
    size = byte_size(bin)
    tail = binary_part(bin, size - 70, 70)

    match?(<<_::binary-size(4), 0x40, _::binary-size(64)>>, tail) or
      match?(<<_::binary-size(3), 0x41, _::binary-size(65)>>, tail) or
      match?(<<_::binary-size(5), 0x00, _::binary-size(64)>>, tail)
  end

  defp read_compact_size(<<n, _::binary>>) when n < 0xFD, do: {:ok, n, 1}
  defp read_compact_size(<<0xFD, n::little-16, _::binary>>), do: {:ok, n, 3}
  defp read_compact_size(<<0xFE, n::little-32, _::binary>>), do: {:ok, n, 5}
  defp read_compact_size(<<0xFF, n::little-64, _::binary>>), do: {:ok, n, 9}
  defp read_compact_size(_), do: :error
end
