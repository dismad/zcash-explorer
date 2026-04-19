defmodule ZcashExplorerWeb.OrchardPoolLive do
  use ZcashExplorerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <p class="text-2xl font-semibold text-gray-900 dark:dark:bg-slate-800 dark:text-slate-100">
      <%= orchard_value(@blockchain_info["valuePools"]) %> <%= @currency %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 15000)

    case Cachex.get(:app_cache, "metrics") do
      {:ok, info} ->
        {:ok, %{"build" => build}} = Cachex.get(:app_cache, "info")
        info = Map.put(info, "build", build)
        currency = if info["chain"] == "main", do: "ZEC", else: "TAZ"
        {:ok, assign(socket, blockchain_info: info, currency: currency)}

      {:error, _reason} ->
        {:ok, assign(socket, blockchain_info: "loading...", currency: "ZEC")}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)

    {:ok, info} = Cachex.get(:app_cache, "metrics")
    {:ok, %{"build" => build}} = Cachex.get(:app_cache, "info")
    info = Map.put(info, "build", build)
    currency = if info["chain"] == "main", do: "ZEC", else: "TAZ"

    {:noreply, assign(socket, blockchain_info: info, currency: currency)}
  end

  defp orchard_value(value_pools) do
    value_pools |> get_value_pools() |> Map.get("orchard")
  end

  defp get_value_pools(value_pools) do
    Enum.map(value_pools, fn %{"id" => name, "chainValue" => value} -> {name, value} end)
    |> Map.new()
  end
end