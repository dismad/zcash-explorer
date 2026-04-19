defmodule ZcashExplorerWeb.BlockController do
  use ZcashExplorerWeb, :controller

  def get_block(conn, %{"hash" => hash}) do
    {:ok, basic_block_data} = Zcashex.getblock(hash, 1)

    case length(basic_block_data["tx"]) do
      0 ->
        {:error, :no_tx}

      n when n <= 250 ->
        {:ok, block_data} = Zcashex.getblock(hash, 2)
        block_data = Zcashex.Block.from_map(block_data)
        height = block_data.height

        render(conn, "index.html",
          block_data: block_data,
          block_subsidy: nil,
          page_title: "Zcash block #{height}"
        )

      n when n > 250 ->
        render(conn, "basic_block.html",
          block_data: basic_block_data,
          page_title: "Zcash block #{hash}"
        )
    end
  end

  def index(conn, params) do
    max_concurrency = System.schedulers_online() * 2
    limit = String.to_integer(Map.get(params, "limit", "20"))

    block = params["block"]

    from_block =
      if is_nil(block) do
        case Zcashex.getblockcount() do
          {:ok, n} ->
            n
        end
      else
        String.to_integer(block)
      end

    to_block = max(from_block - limit, 0)
    disable_previous = if is_nil(block), do: true, else: false
    disable_next = if from_block == 0, do: true, else: false

    blocks =
      Enum.to_list(to_block..from_block)
      |> Enum.map(fn x ->
        {:ok, block} = Zcashex.getblock(x, 2)
        block["hash"]
      end)

    blocks_data =
      blocks
      |> Task.async_stream(fn block -> Zcashex.getblockheader(block) end,
        max_concurrency: max_concurrency,
        ordered: false
      )
      |> Enum.to_list()
      |> Enum.map(fn {_task, {:ok, res}} -> res end)
      |> Enum.reverse()

    render(conn, "blocks.html",
      blocks_data: blocks_data,
      disable_next: disable_next,
      disable_previous: disable_previous,
      date: "",
      previous: from_block + limit,
      next: to_block,
      page_title: "Zcash latest blocks"
    )
  end
end
