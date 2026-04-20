defmodule ZcashExplorerWeb.SearchController do
  use ZcashExplorerWeb, :controller

  def search(conn, params) do
    qs = String.trim(params["qs"] || "")

    if qs == "" do
      conn
      |> put_flash(:error, "Please enter a block height, transaction ID, or address")
      |> redirect(to: "/")
    else
      case classify_input(qs) do
        :block_height ->
          redirect(conn, to: "/blocks/#{qs}")

        :block_hash ->
          redirect(conn, to: "/blocks/#{qs}")

        :transaction ->
          redirect(conn, to: "/transactions/#{qs}")

        :transparent_address ->
          redirect(conn, to: "/address/#{qs}")

        :shielded_address ->
          redirect(conn, to: "/address/#{qs}")

        :unified_address ->
          redirect(conn, to: "/ua/#{qs}")

        :unknown ->
          conn
          |> put_flash(:error, "No matching block, transaction, or address found.")
          |> redirect(to: "/")
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # CLASSIFIER USING LEADING-ZEROS HEURISTIC (threshold = 10)
  # ─────────────────────────────────────────────────────────────
  defp classify_input(qs) do
    # Count leading zeros
    leading_zeros =
      qs
      |> String.graphemes()
      |> Enum.take_while(&(&1 == "0"))
      |> length()

    total_length = String.length(qs)

    # Debug output
    IO.puts("=== SEARCH CLASSIFIER (leading-zeros ≥ 10 heuristic) ===")
    IO.inspect(%{
      input: qs,
      leading_zeros: leading_zeros,
      length: total_length,
      is_numeric: Regex.match?(~r/^\d+$/, qs),
      is_64hex: total_length == 64 && Regex.match?(~r/^[0-9a-f]{64}$/, qs)
    }, label: "Raw data")

    cond do
      # 1. Purely numeric → always block height
      Regex.match?(~r/^\d+$/, qs) ->
        IO.puts("→ CLASSIFIED AS BLOCK HEIGHT (leading zeros: #{leading_zeros})")
        :block_height

      # 2. 64-hex string → use your new threshold
      total_length == 64 && Regex.match?(~r/^[0-9a-f]{64}$/, qs) ->
        if leading_zeros >= 10 do
          IO.puts("→ CLASSIFIED AS BLOCK HASH (leading zeros: #{leading_zeros} ≥ 10)")
          :block_hash
        else
          IO.puts("→ CLASSIFIED AS TRANSACTION ID (leading zeros: #{leading_zeros} < 10)")
          :transaction
        end

      # 3. Addresses
      String.starts_with?(qs, "t1") || String.starts_with?(qs, "t3") ->
        IO.puts("→ CLASSIFIED AS TRANSPARENT ADDRESS")
        :transparent_address

      String.starts_with?(qs, "z") ->
        IO.puts("→ CLASSIFIED AS SHIELDED ADDRESS")
        :shielded_address

      String.starts_with?(qs, "u1") ->
        IO.puts("→ CLASSIFIED AS UNIFIED ADDRESS")
        :unified_address

      true ->
        IO.puts("→ CLASSIFIED AS UNKNOWN")
        :unknown
    end
  end
end