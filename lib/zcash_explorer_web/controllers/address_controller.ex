defmodule ZcashExplorerWeb.AddressController do
  use ZcashExplorerWeb, :controller

  def get_address(conn, %{"address" => address, "s" => s, "e" => e}) do
    if String.starts_with?(address, ["zc", "zs"]) do
      qr =
        address
        |> EQRCode.encode()
        |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
        |> Base.encode64()

      render(conn, "z_address.html",
        address: address,
        qr: qr,
        page_title: "Zcash Shielded Address"
      )
    end

    {:ok, info} = Cachex.get(:app_cache, "metrics")
    blocks = info["blocks"]

    e = String.to_integer(e)
    s = String.to_integer(s)

    # if requesting for a block that's not yet mined, cap the request to the latest block
    capped_e = if e > blocks, do: blocks, else: e

    {:ok, balance} = Zcashex.getaddressbalance(address)
    # {:ok, deltas} = Zcashex.getaddressdeltas(address, s, capped_e, true)
    {:ok, txs} = Zcashex.getaddresstxids(address, s, e)

    txs =
      txs
      |> Enum.map(fn x ->
        {:ok, tx} = Zcashex.getrawtransaction(x, 1)

        value =
          Map.get(tx, "vout")
          |> Enum.filter(fn out ->
            out["scriptPubKey"]["addresses"] |> List.first() == address
          end)
          |> Enum.map(fn vout -> Map.get(vout, "value") end)
          |> Enum.sum()

        Map.put(tx, "satoshi", value)
        tx
      end)

    txs = txs |> Enum.reverse()

    qr =
      address
      |> EQRCode.encode()
      |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
      |> Base.encode64()

    render(conn, "address.html",
      address: address,
      balance: balance,
      txs: txs,
      qr: qr,
      end_block: e,
      start_block: s,
      latest_block: blocks,
      capped_e: capped_e,
      page_title: "Zcash Address #{address}"
    )
  end

  def get_address(conn, %{"address" => address}) do
    if String.starts_with?(address, ["zc", "zs"]) do
      qr =
        address
        |> EQRCode.encode()
        |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
        |> Base.encode64()

      render(conn, "z_address.html",
        address: address,
        qr: qr,
        page_title: "Zcash Shielded Address"
      )
    end

    _c = 5
    {:ok, info} = Cachex.get(:app_cache, "metrics")
    latest_block = info["blocks"]
    e = latest_block

    limit = 20
    s = e - limit
    {:ok, balance} = Zcashex.getaddressbalance(address)
    # {:ok, deltas} = Zcashex.getaddressdeltas(address, s, e, true)
    # txs = Map.get(deltas, "deltas") |> Enum.reverse()
    {:ok, txs} = Zcashex.getaddresstxids(address, s, e)

    txs =
      txs
      |> Enum.map(fn x ->
        {:ok, tx} = Zcashex.getrawtransaction(x, 1)

        value =
          Map.get(tx, "vout")
          |> Enum.map(fn vout ->
            case vout do
              %{"scriptPubKey" => %{"addresses" => [^address]}} ->
                Map.get(vout, "valueZat", 0)

              _ ->
                0
            end
          end)
          |> Enum.sum()

        tx = Map.put(tx, "satoshis", value)
        tx
      end)

    txs = txs |> Enum.reverse()

    txs |> List.first() |> IO.inspect(label: "first tx")
    txs = txs |> Enum.reverse()

    qr =
      address
      |> EQRCode.encode()
      |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
      |> Base.encode64()

    render(conn, "address.html",
      address: address,
      balance: balance,
      txs: txs,
      qr: qr,
      end_block: e,
      start_block: s,
      latest_block: latest_block,
      capped_e: nil,
      page_title: "Zcash Address #{address}"
    )
  end

  def get_ua(conn, %{"address" => ua}) do
    {:ok, details} = Zcashex.z_listunifiedreceivers(ua)
    IO.inspect(details)
    orchard_present = Map.has_key?(details, "orchard")
    transparent_present = Map.has_key?(details, "p2pkh")
    sapling_present = Map.has_key?(details, "sapling")

    if String.starts_with?(ua, ["u"]) do
      u_qr =
        ua
        |> EQRCode.encode()
        |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
        |> Base.encode64()

      render(conn, "u_address.html",
        address: ua,
        qr: u_qr,
        page_title: "Zcash Unified Address",
        orchard_present: orchard_present,
        transparent_present: transparent_present,
        sapling_present: sapling_present,
        details: details
      )
    end
  end
end
