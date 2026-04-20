defmodule ZcashExplorerWeb.ShieldedAddressLive do
  use Phoenix.LiveView, layout: false

  def mount(%{"address" => address} = _params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    # Reliable detection
    is_unified = String.starts_with?(address, "u1")
    is_sapling = String.starts_with?(address, "z") && !is_unified

    # For Unified Addresses: get all component receivers
    {details, orchard_present, sapling_present, transparent_present} =
      if is_unified do
        case Zcashex.z_listunifiedreceivers(address) do
          {:ok, receivers} ->
            {
              %{
                "orchard" => receivers["orchard"],
                "sapling" => receivers["sapling"],
                "p2pkh"   => receivers["p2pkh"]
              },
              Map.has_key?(receivers, "orchard") && receivers["orchard"] != nil,
              Map.has_key?(receivers, "sapling") && receivers["sapling"] != nil,
              Map.has_key?(receivers, "p2pkh") && receivers["p2pkh"] != nil
            }
          _ ->
            {%{}, false, false, false}
        end
      else
        {%{}, false, false, false}
      end

    qr = generate_qr(address)

    {:ok,
     assign(socket,
       address: address,
       is_unified: is_unified,
       is_sapling: is_sapling,
       details: details,
       orchard_present: orchard_present,
       sapling_present: sapling_present,
       transparent_present: transparent_present,
       qr: qr,
       zcash_network: network,
       page_title: "Zcash Shielded Address #{address}"
     )}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title><%= @page_title %></title>
        <link rel="stylesheet" href="/assets/app.css">
      </head>
      <body class="bg-gray-50 dark:bg-gray-900">

        <!-- Exact same header as AddressLive -->
        <header class="bg-indigo-600 text-white h-14 flex items-center">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
            <div class="flex items-center justify-between h-full">
              <div class="flex items-center gap-x-3 flex-shrink-0">
                <a href="/" class="flex items-center">
                  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
                </a>
                <a href="/" class="text-xl font-semibold tracking-tight">Zcash Block Explorer</a>
              </div>

              <div class="flex-1 max-w-2xl mx-8 mt-4">
                <form action="/search" class="relative">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 01-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>
                  <input name="qs" type="search"
                    class="block w-full pl-11 pr-4 py-2.5 bg-white/20 hover:bg-white/30 focus:bg-white focus:text-gray-900 placeholder:text-white/70 text-white rounded-3xl text-base focus:outline-none focus:ring-2 focus:ring-white/50 transition-all"
                    placeholder="transaction / block / address">
                </form>
              </div>

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

        <div class="mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">

            <!-- Left Column - Details + QR -->
            <div class="lg:col-span-4">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6 sticky top-8">
                <div class="text-sm text-gray-500 mb-2">
                  <%= if @is_unified do %>
                    Details for the Zcash Unified Address:
                  <% else %>
                    Details for the Zcash Shielded Address:
                  <% end %>
                </div>
                <div class="font-mono text-sm break-all mb-8"><%= @address %></div>

                <div class="flex justify-center mb-10">
                  <img src={"data:image/png;base64,#{@qr}"} class="w-56 h-56 border border-gray-200 dark:border-gray-700 rounded-3xl" alt="QR Code" />
                </div>

                <div class="text-center text-indigo-600 dark:text-indigo-400 text-sm font-medium">
                  <%= if @is_unified do %>
                    Unified Address
                  <% else %>
                    Shielded Sapling Address
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Right Column - Content -->
            <div class="lg:col-span-8">
              <div class="bg-white dark:bg-gray-800 shadow rounded-3xl p-6">
                <h2 class="text-2xl font-semibold tracking-tight mb-8">
                  <%= if @is_unified do %>
                    You are viewing the details of a 
                    <span class="text-indigo-600">Zcash Unified Address</span>
                  <% else %>
                    You are viewing a 
                    <span class="text-indigo-600">Zcash Shielded Sapling Address</span>
                  <% end %>
                </h2>

                <%= if @is_unified do %>
                  <!-- UA component breakdown -->
                  <div class="space-y-6">
                    <%= if @orchard_present do %>
                      <div class="flex gap-4 border border-gray-200 dark:border-gray-700 rounded-2xl p-5">
                        <div class="shrink-0 w-12 h-12 bg-indigo-50 dark:bg-indigo-900 rounded-xl flex items-center justify-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                          </svg>
                        </div>
                        <div class="flex-1">
                          <div class="text-emerald-600 font-medium text-xs">Orchard Address</div>
                          <div class="font-mono text-sm break-all mt-1"><%= @details["orchard"] %></div>
                        </div>
                      </div>
                    <% end %>

                    <%= if @sapling_present do %>
                      <div class="flex gap-4 border border-gray-200 dark:border-gray-700 rounded-2xl p-5">
                        <div class="shrink-0 w-12 h-12 bg-indigo-50 dark:bg-indigo-900 rounded-xl flex items-center justify-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                          </svg>
                        </div>
                        <div class="flex-1">
                          <div class="text-emerald-600 font-medium text-xs">Sapling Address</div>    
                          <div class="font-mono text-sm break-all mt-1"> <%= @details["sapling"] %></div>
                        </div>
                      </div>
                    <% end %>

                    <%= if @transparent_present do %>
                      <div class="flex gap-4 border border-gray-200 dark:border-gray-700 rounded-2xl p-5">
                        <div class="shrink-0 w-12 h-12 bg-indigo-50 dark:bg-indigo-900 rounded-xl flex items-center justify-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                          </svg>
                        </div>
                        <div class="flex-1">
                          <div class="text-emerald-600 font-medium text-xs">Transparent Address</div>
                          <a href={"/address/#{@details["p2pkh"]}"} class="font-mono text-sm break-all mt-1 hover:text-indigo-600">
                            <%= @details["p2pkh"] %>
                          </a>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <!-- Pure Sapling address -->
                  <div class="text-center py-12">
                    <div class="mx-auto w-16 h-16 bg-indigo-100 dark:bg-indigo-900 rounded-2xl flex items-center justify-center mb-6">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                      </svg>
                    </div>
                    <h3 class="text-xl font-semibold mb-2">Shielded Sapling Address</h3>  
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

      </body>
    </html>
    """
  end

  defp generate_qr(address) do
    address
    |> EQRCode.encode()
    |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
    |> Base.encode64()
  end
end