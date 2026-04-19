defmodule ZcashExplorerWeb.MempoolInfoLive do
  use ZcashExplorerWeb, :live_view
  @impl true
  def render(assigns) do
    ~H"""
    <p class="text-2xl font-semibold text-gray-900 dark:dark:bg-slate-800 dark:text-slate-100">
    <%= @mempool_info %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 1000)

    case Cachex.get(:app_cache, "raw_mempool") do
      {:ok, info} ->
        {:ok, assign(socket, :mempool_info, length(info))}

      {:error, _reason} ->
        {:ok, assign(socket, :mempool_info, "loading...")}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 1000)
    {:ok, info} = Cachex.get(:app_cache, "raw_mempool")
    {:noreply, assign(socket, :mempool_info, length(info))}
  end
end
