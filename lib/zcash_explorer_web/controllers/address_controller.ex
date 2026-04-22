defmodule ZcashExplorerWeb.AddressController do
  use ZcashExplorerWeb, :controller

  def get_address(conn, %{"address" => address} = params) do
    {:ok, info} = Cachex.get(:app_cache, "metrics")
    latest_block = info["blocks"]

    # Pagination (default last 20 blocks)
    e = params["e"] |> parse_int(latest_block)
    s = params["s"] |> parse_int(latest_block - 20)
    capped_e = min(e, latest_block)

    {:ok, balance} = Zcashex.getaddressbalance(address)

    {:ok, txids} = Zcashex.getaddresstxids(address, s, capped_e)

    txs = enrich_transactions(txids, address)

    qr = generate_qr(address)

    if String.starts_with?(address, ["zc", "zs"]) do
      render(conn, "z_address.html",
        address: address,
        qr: qr,
        page_title: "Zcash Shielded Address"
      )
    else
      render(conn, "address.html",
        address: address,
        balance: balance,
        txs: txs,
        qr: qr,
        end_block: capped_e,
        start_block: s,
        latest_block: latest_block,
        capped_e: capped_e,
        page_title: "Zcash Address #{address}"
      )
    end
  end

  def get_ua(conn, %{"address" => ua}) do
    {:ok, details} = Zcashex.z_listunifiedreceivers(ua)

    qr = generate_qr(ua)

    render(conn, "u_address.html",
      address: ua,
      qr: qr,
      page_title: "Zcash Unified Address",
      orchard_present: Map.has_key?(details, "orchard"),
      transparent_present: Map.has_key?(details, "p2pkh"),
      sapling_present: Map.has_key?(details, "sapling"),
      details: details
    )
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> default
    end
  end
  defp parse_int(val, _default), do: val

  defp generate_qr(address) do
    address
    |> EQRCode.encode()
    |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
    |> Base.encode64()
  end

  defp enrich_transactions(txids, address) do
    txids
    |> Enum.map(fn txid ->
      {:ok, tx} = Zcashex.getrawtransaction(txid, 1)

      incoming = sum_matching_vout(tx, address)
      outgoing = sum_matching_vin(tx, address)

      net_value = incoming - outgoing

      tx
      |> Map.put("satoshis", net_value)
      |> Map.put("txid", txid)
    end)
    |> Enum.reverse()
  end

  defp sum_matching_vout(tx, address) do
    (tx["vout"] || [])
    |> Enum.map(fn vout ->
      case vout do
        %{"scriptPubKey" => %{"addresses" => [^address]}} ->
          Map.get(vout, "valueZat", 0)
        _ ->
          0
      end
    end)
    |> Enum.sum()
  end

  # FIXED: Use Enum.at/2 instead of invalid list[index] syntax
  defp sum_matching_vin(tx, address) do
    (tx["vin"] || [])
    |> Enum.map(fn vin ->
      if Map.has_key?(vin, "coinbase") do
        0
      else
        prev_txid = vin["txid"]
        prev_vout_idx = vin["vout"]

        {:ok, prev_tx} = Zcashex.getrawtransaction(prev_txid, 1)

        # Safe list access
        prev_vout = Enum.at(prev_tx["vout"] || [], prev_vout_idx)

        case prev_vout do
          %{"scriptPubKey" => %{"addresses" => [^address]}} ->
            Map.get(prev_vout, "valueZat", 0)
          _ ->
            0
        end
      end
    end)
    |> Enum.sum()
  end

  def redirect_ua(conn, %{"address" => address}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: "/address/#{URI.encode_www_form(address)}")
  end

  def redirect_z(conn, %{"address" => address}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: "/address/#{URI.encode_www_form(address)}")
  end




end