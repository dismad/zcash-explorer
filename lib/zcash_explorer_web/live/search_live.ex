defmodule ZcashExplorerWeb.SearchLive do
  use ZcashExplorerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :qs, "")}
  end

  @impl true
  def handle_event("search", %{"qs" => qs}, socket) do
    qs = String.trim(qs)

    tasks = [
      Task.async(fn -> Zcashex.getblock(qs, 0) end),
      Task.async(fn -> Zcashex.getrawtransaction(qs, 0) end),
      Task.async(fn -> Zcashex.validateaddress(qs) end),
      Task.async(fn -> Zcashex.z_validateaddress(qs) end)
    ]

    results = Task.yield_many(tasks, 3000)

    block_resp = get_task_result(results, 0)
    tx_resp    = get_task_result(results, 1)
    taddr_resp = get_task_result(results, 2)
    zaddr_resp = get_task_result(results, 3)

    cond do
      is_valid_block?(block_resp)   -> {:noreply, push_navigate(socket, to: "/blocks/#{qs}")}
      is_valid_tx?(tx_resp)         -> {:noreply, push_navigate(socket, to: "/transactions/#{qs}")}
      is_valid_taddr?(taddr_resp)   -> {:noreply, push_navigate(socket, to: "/address/#{qs}")}
      is_valid_zaddr?(zaddr_resp)   -> {:noreply, push_navigate(socket, to: "/address/#{qs}")}
      is_valid_unified_address?(zaddr_resp) -> {:noreply, push_navigate(socket, to: "/ua/#{qs}")}
      true ->
        {:noreply, put_flash(socket, :error, "No matching block, transaction, or address found.")}
    end
  end

  defp get_task_result(results, index) do
    case Enum.at(results, index) do
      {_, {:ok, result}} -> result
      _ -> {:error, :timeout}
    end
  end

  # Validation helpers (same logic as before, cleaned up)
  defp is_valid_block?({:ok, _}), do: true
  defp is_valid_block?(_), do: false

  defp is_valid_tx?({:ok, _}), do: true
  defp is_valid_tx?(_), do: false

  defp is_valid_taddr?({:ok, %{"isvalid" => true}}), do: true
  defp is_valid_taddr?(_), do: false

  defp is_valid_zaddr?({:ok, %{"isvalid" => true}}), do: true
  defp is_valid_zaddr?(_), do: false

  defp is_valid_unified_address?({:ok, %{"isvalid" => true, "type" => "unified"}}), do: true
  defp is_valid_unified_address?({:ok, %{"isvalid" => true, "address_type" => "unified"}}), do: true
  defp is_valid_unified_address?(_), do: false
end