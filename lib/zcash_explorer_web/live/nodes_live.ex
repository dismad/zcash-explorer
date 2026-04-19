defmodule ZcashExplorerWeb.NodesLive do
  use Phoenix.LiveView, layout: false

  @impl true
  def mount(_params, session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    standalone = Map.get(session, "standalone", true)

    if connected?(socket), do: Process.send_after(self(), :update, 5000)

    # Get peer list
    {:ok, nodes} = Cachex.get(:app_cache, "zcash_nodes")

    # Get local node info for the top summary
    {:ok, node_info} = Cachex.get(:app_cache, "info")

    {:ok, assign(socket,
      zcash_nodes: nodes || [],
      node_info: node_info || %{},
      zcash_network: network,
      standalone: standalone
    )}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 5000)
    {:ok, nodes} = Cachex.get(:app_cache, "zcash_nodes")
    {:noreply, assign(socket, :zcash_nodes, nodes || [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Nodes - Zcash Explorer</title>
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">
        <%= if @standalone do %>
          <header class="bg-indigo-600 text-white h-14 flex items-center">
	  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
	    <div class="flex items-center justify-between h-full">
	      
	      <!-- Logo + Title -->
	      <div class="flex items-center gap-x-3 flex-shrink-0">
		<a href="/" class="flex items-center">
		  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
		</a>
		<a href="/" class="text-xl font-semibold tracking-tight">Zcash Block Explorer</a>
	      </div>

	      <!-- Search Bar -->
	      <div class="flex-1 max-w-2xl mx-8 mt-4">
		<form action="/search" class="relative">
		  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
		    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
		      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 01-14 0 7 7 0 0114 0z" />
		    </svg>
		  </div>
		  <input 
		    name="qs" 
		    type="search"
		    class="block w-full pl-11 pr-4 py-2.5 bg-white/20 hover:bg-white/30 focus:bg-white focus:text-gray-900 placeholder:text-white/70 text-white rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-white/50 transition-all"
		    placeholder="transaction / block / address"
		  >
		</form>
	      </div>

	      <!-- Desktop Navigation -->
	      <div class="hidden lg:flex items-center gap-x-8 text-sm font-medium flex-shrink-0">
		<a href="/mempool" class="hover:text-white/80 transition-colors">Mempool</a>
		<a href="/blocks" class="hover:text-white/80 transition-colors">Blocks</a>
		<a href="/nodes" class="hover:text-white/80 transition-colors">Nodes</a>
		<a href="/broadcast" class="hover:text-white/80 transition-colors">Broadcast</a>
		<%= if @zcash_network != "testnet" do %>
		  <a href="/vk" class="hover:text-white/80 transition-colors">Viewing Key</a>
		<% end %>
	      </div>
	    </div>
	  </div>
	</header>
        <% end %>

        <!-- Node Info Summary -->
        <div class="max-w-7xl mx-auto px-4 py-6">
          <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
            <h2 class="text-lg font-semibold mb-4">Local Node Info</h2>
            <dl class="grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
              <div><dt class="text-gray-500">Version</dt><dd class="font-medium"><%= @node_info["build"] || "—" %></dd></div>
              <div><dt class="text-gray-500">Chain</dt><dd class="font-medium"><%= @node_info["chain"] || "—" %></dd></div>
              <div><dt class="text-gray-500">Blocks</dt><dd class="font-medium"><%= @node_info["blocks"] || "—" %></dd></div>
              <div><dt class="text-gray-500">Connections</dt><dd class="font-medium"><%= length(@zcash_nodes) %></dd></div>
            </dl>
          </div>
        </div>

        <!-- Peers Table -->
        <div class="w-full px-4">
          <div class="shadow overflow-hidden border-gray-200 rounded-lg overflow-x-auto">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3">Address</th>
                  <th scope="col" class="px-4 py-3">Version</th>
                  <th scope="col" class="px-4 py-3">Services</th>
                  <th scope="col" class="px-4 py-3">Direction</th>
                  <th scope="col" class="px-4 py-3">Ping (ms)</th>
                  <th scope="col" class="px-4 py-3">Connected</th>
                  <th scope="col" class="px-4 py-3">Synced Blocks</th>
                  <th scope="col" class="px-4 py-3">Starting Height</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200 dark:bg-gray-800 dark:divide-gray-700">
                <%= for node <- @zcash_nodes do %>
                  <tr class="hover:bg-gray-50 dark:hover:bg-gray-600">
                    <td class="px-6 py-4 whitespace-nowrap font-mono text-sm"><%= node["addr"] %></td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm"><%= node["subver"] || "—" %></td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm font-mono"><%= node["services"] || "—" %></td>
                    <td class="px-4 py-4 whitespace-nowrap">
                      <%= if node["inbound"] do %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">Inbound</span>
                      <% else %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">Outbound</span>
                      <% end %>
                    </td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm"><%= node["pingtime"] || "—" %> ms</td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm"><%= relative_time(node["conntime"]) %></td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm"><%= node["synced_blocks"] || "—" %></td>
                    <td class="px-4 py-4 whitespace-nowrap text-sm"><%= node["startingheight"] || "—" %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp relative_time(nil), do: "—"
  defp relative_time(timestamp) when is_integer(timestamp) do
    Timex.from_unix(timestamp) |> Timex.format!("{relative}", :relative)
  end
  defp relative_time(_), do: "—"
end