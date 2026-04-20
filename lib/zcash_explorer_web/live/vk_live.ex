defmodule ZcashExplorerWeb.VkLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def render(%{message: %{"txs" => []}} = assigns) do
    ~H"""
    <div id="clogsholder" class="text-green-400 font-mono break-all overscroll-auto overflow-auto mx-16 h-28 min-h-full border-solid rounded-md border-opacity-25 shadow-inner border-4 border-light-blue-500" phx-hook="VkContainerLog">
      <div id="clogs" class="min-h-full">
        <%= @message["message"] %>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if length(@message["txs"]) > 0 do %>
      <div class="shadow overflow-hidden border-b border-gray-200 rounded-lg overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-midnight-500 uppercase tracking-wider">Tx</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-midnight-500 uppercase tracking-wider">Amount</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-midnight-500 uppercase tracking-wider">Address</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-midnight-500 uppercase tracking-wider">Date</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-midnight-500 uppercase tracking-wider">Memo</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for tx <- @message["txs"] do %>
              <tr class="hover:bg-gray-50 dark:hover:bg-gray-600">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-indigo-600 hover:text-indigo-500">
                  <a href={"/transactions/#{tx["tx"]}"}><%= tx["tx"] %></a>
                </td>
                <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                  <%= zatoshi_to_zec(tx["amount"]) %> ZEC
                </td>
                <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                  <a href={"/address/#{tx["address"]}"}><%= tx["address"] %></a>
                </td>
                <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                  <%= mined_time_rel(tx["datetime"]) %>
                </td>
                <td class="px-4 py-4 whitespace-nowrap text-sm font-medium">
                  <%= tx["memo"] %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div id="clogsholder" class="text-green-400 font-mono break-all overscroll-auto overflow-auto mx-16 h-28 min-h-full border-solid rounded-md border-opacity-25 shadow-inner border-4 border-light-blue-500" phx-hook="VkContainerLog">
        <div id="clogs" class="min-h-full">
          <%= @message["message"] %>
        </div>
      </div>
    <% end %>
    """
  end

  # ------------------------------------------------------------------
  # Local helpers (replaces the old AddressView / BlockView calls)
  # ------------------------------------------------------------------
  defp zatoshi_to_zec(amount) when is_number(amount) do
    amount
    |> Decimal.from_float()
    |> Decimal.div(Decimal.new(100_000_000))
    |> Decimal.round(8)
    |> Decimal.to_string(:normal)
  end

  defp zatoshi_to_zec(_), do: "0.00000000"

  defp mined_time_rel(unix_timestamp) when is_integer(unix_timestamp) do
    Timex.from_unix(unix_timestamp) |> Timex.format!("{relative}", :relative)
  end

  defp mined_time_rel(_), do: "—"

  # ------------------------------------------------------------------
  # Your original mount / handle_info / terminate logic (unchanged)
  # ------------------------------------------------------------------
  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(socket, :message, %{
       "message" => "Starting to import the VK .",
       "container_id" => Map.get(session, "container_id"),
       "txs" => []
     })}
  end

  @impl true
  def handle_info(:update, socket) do
    if length(socket.assigns.message["txs"]) == 0 do
      Process.send_after(self(), :update, 3000)
    end

    cmd = MuonTrap.cmd("docker", ["logs", socket.assigns.message["container_id"]])
    logs = elem(cmd, 0) |> Phoenix.HTML.Format.text_to_html()

    {:noreply,
     assign(socket, :message, %{
       "message" => logs,
       "container_id" => socket.assigns.message["container_id"],
       "txs" => socket.assigns.message["txs"]
     })}
  end

  @impl true
  def handle_info({:received_txs, txs}, socket) do
    Cachex.decr!(:app_cache, "nbjobs")

    {:noreply,
     assign(socket, :message, %{
       "message" => "Got list of txs",
       "container_id" => socket.assigns.message["container_id"],
       "txs" => txs
     })}
  end

  @impl true
  def terminate(reason, socket) do
    container_id = socket.assigns.message["container_id"]

    if disconnected?(reason) do
      Cachex.decr!(:app_cache, "nbjobs")
      MuonTrap.cmd("docker", ["stop", container_id])
    end
  end

  defp disconnected?(reason) do
    case reason do
      :shutdown -> true
      {:shutdown, shutdown_reason} when shutdown_reason in [:left, :closed] -> true
      _ -> false
    end
  end
end
