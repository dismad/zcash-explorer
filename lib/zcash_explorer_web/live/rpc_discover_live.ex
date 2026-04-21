defmodule ZcashExplorerWeb.RpcDiscoverLive do
  use Phoenix.LiveView, layout: false

  # Dangerous methods → ONLY static realistic curl (NEVER call live node)
  # sendrawtransaction added back per your request
  @dangerous_methods [
    "generate",
    "reconsiderblock",
    "submitblock",
    "addnode",
    "getblocktemplate",
    "invalidateblock",
    "stop",
    "sendrawtransaction"
  ]

  # Methods that get realistic curl examples + real (or sanitized) live results
  @dynamic_example_methods [
    "getrawtransaction",
    "getblock",
    "getaddresstxids",
    "getaddressutxos",
    "getaddressbalance",
    "getblockhash",
    "getblockheader",
    "validateaddress",
    "z_validateaddress",
    "z_gettreestate",
    "z_listunifiedreceivers",
    "z_getsubtreesbyindex",
    "gettxout",
    "getpeerinfo"
  ]

  # Public addresses for examples
  @public_t_address "t1VRaZAdpoEqgMtweYq2q45CpUgbsRZdiKf"
  @public_ua "u1gmpqfpt8uh93qukuk8607f2ur9mc6e2rskyj5gj9xmfupa635v57g503jpp98xdlgswkync9zrrxg7jhn4llgx7yqt0pmh7e0sz4y4yt"

  def mount(_params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"

    {:ok, schema} =
      GenServer.call(Zcashex, {:call_endpoint, "rpc.discover", []}, 10_000)

    methods = schema["methods"] || []

    {:ok,
     assign(socket,
       schema: schema,
       methods: methods,
       selected_method: nil,
       example_curl: nil,
       live_result: nil,
       zcash_network: network,
       page_title: "Zebra RPC Explorer"
     )}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <title><%= @page_title %></title>
        <link rel="stylesheet" href="/assets/app.css">
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()}>
        <script src="/js/app.js"></script>
      </head>
      <body class="bg-gray-50 dark:bg-gray-900 flex flex-col min-h-screen">

        <header class="bg-gradient-to-r from-blue-950 via-blue-900 to-blue-800 text-white sticky top-0 z-50 shadow-md">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="h-14 flex items-center justify-between">
              <!-- Logo + Title -->
              <div class="flex items-center gap-x-3 flex-shrink-0">
                <a href="/" class="flex items-center">
                  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
                </a>
                <a href="/" class="text-xl font-semibold tracking-tight">Zcash Block Explorer</a>
              </div>
            </div>
          </div>
        </header>

        <div class="flex-1 w-full mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-col lg:grid lg:grid-cols-12 gap-6 lg:gap-8 h-full lg:h-[calc(100vh-4rem)] min-h-0">

            <!-- Left Sidebar -->
            <div class="lg:col-span-4 bg-white dark:bg-gray-800 shadow rounded-3xl flex flex-col">
              <div class="flex-shrink-0 p-6 border-b border-gray-100 dark:border-gray-700">
                <h1 class="text-2xl font-semibold mb-5 flex items-center gap-x-3">
                  <span>Zebra RPC Methods</span>
                  <span class="text-xs font-normal bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300 px-3 py-1 rounded-3xl">
                    <%= length(@methods) %> total
                  </span>
                </h1>

                <input type="text"
                       phx-keyup="search"
                       phx-debounce="200"
                       placeholder="Filter methods..."
                       class="w-full pl-10 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-2xl focus:outline-none focus:ring-2 focus:ring-indigo-500">
              </div>

              <div class="flex-1 min-h-0 overflow-auto p-6 pt-2">
                <div class="space-y-1 pr-2">
                  <%= for method <- @methods do %>
                    <button phx-click="select_method"
                            phx-value-name={method["name"]}
                            class={"w-full text-left px-5 py-3.5 rounded-3xl transition-all hover:shadow-md border border-transparent font-mono text-base active:scale-[0.98] " <>
                              if @selected_method && @selected_method["name"] == method["name"] do
                                "bg-indigo-600 text-white shadow-md"
                              else
                                "hover:bg-gray-50 dark:hover:bg-gray-700"
                              end}>
                      <%= method["name"] %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Right Panel -->
            <div class="lg:col-span-8 bg-white dark:bg-gray-800 shadow rounded-3xl flex flex-col overflow-hidden">
              <div class="flex-1 p-6 lg:p-8 overflow-auto">
                <%= if @selected_method do %>
                  <div class="prose dark:prose-invert max-w-none">
                    <div class="flex items-center gap-x-3 mb-6">
                      <.method_icon tags={@selected_method["tags"]} size="lg" />
                      <h2 class="text-2xl sm:text-3xl font-semibold font-mono m-0"><%= @selected_method["name"] %></h2>
                    </div>

                    <.method_tags tags={@selected_method["tags"]} large={true} />

                    <p class="text-lg text-gray-600 dark:text-gray-400 mt-4"><%= @selected_method["summary"] %></p>
                    <p class="mt-6 leading-relaxed"><%= @selected_method["description"] %></p>

                    <!-- Curl Example -->
                    <h3 class="mt-10 text-xl font-semibold">Example curl command</h3>
                    <pre class="mt-4 p-5 sm:p-6 bg-gray-900 text-gray-100 dark:bg-black rounded-3xl text-sm overflow-x-auto font-mono whitespace-pre border border-gray-800"><%= @example_curl %></pre>

                    <!-- Parameters -->
                    <%= if @selected_method["params"] && length(@selected_method["params"]) > 0 do %>
                      <h3 class="mt-10 text-xl font-semibold">Parameters</h3>
                      <div class="mt-4 space-y-6">
                        <%= for param <- @selected_method["params"] do %>
                          <div class="border border-gray-200 dark:border-gray-700 rounded-2xl p-5 sm:p-6">
                            <div class="flex justify-between items-start">
                              <div>
                                <span class="font-mono font-medium"><%= param["name"] %></span>
                                <%= if param["required"] do %>
                                  <span class="ml-2 text-xs px-3 py-1 bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300 rounded-3xl">required</span>
                                <% end %>
                              </div>
                            </div>
                            <p class="text-sm text-gray-500 mt-3"><%= param["description"] %></p>
                          </div>
                        <% end %>
                      </div>
                    <% end %>

                    <!-- Real result (safe for all methods now) -->
                    <%= if @live_result do %>
                      <h3 class="mt-10 text-xl font-semibold">Real Result from Node (Live)</h3>
                      <pre class="mt-4 p-5 sm:p-6 bg-gray-900 text-gray-100 dark:bg-black rounded-3xl text-sm overflow-x-auto font-mono border border-gray-800"><%= @live_result %></pre>
                    <% end %>
                  </div>
                <% else %>
                  <div class="flex flex-col items-center justify-center h-96 text-center">
                    <div class="text-7xl mb-8 opacity-30">🔎</div>
                    <h3 class="text-3xl font-semibold text-gray-400">Select a method on the left</h3>
                    <p class="text-gray-500 mt-4 max-w-xs">Tap any RPC method to see a realistic curl example + documentation.</p>
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

  # ==================== CURL EXAMPLE LOGIC ====================
  defp curl_example(method) do
    name = method["name"]

    if name in @dangerous_methods do
      case name do
        "generate" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "generate",
              "params": [1]
            }'
        """

        "reconsiderblock" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "reconsiderblock",
              "params": ["0000000000000000000000000000000000000000000000000000000000000000"]
            }'
        """

        "submitblock" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "submitblock",
              "params": ["<hex block data>"]
            }'
        """

        "addnode" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "addnode",
              "params": ["1.2.3.4:8233", "add"]
            }'
        """

        "getblocktemplate" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "getblocktemplate",
              "params": []
            }'
        """

        "invalidateblock" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "invalidateblock",
              "params": ["0000000000000000000000000000000000000000000000000000000000000000"]
            }'
        """

        "stop" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "stop",
              "params": []
            }'
        """

        "sendrawtransaction" -> ~s"""
          curl -X POST http://localhost:18232 \\
            -H "Content-Type: application/json" \\
            -d '{
              "jsonrpc": "2.0",
              "id": "1",
              "method": "sendrawtransaction",
              "params": ["<signed raw tx hex>"]
            }'
        """

        _ -> ""
      end
    else
      ~s"""
      curl -X POST http://localhost:18232 \\
        -H "Content-Type: application/json" \\
        -d '{
          "jsonrpc": "2.0",
          "id": "1",
          "method": "#{name}",
          "params": []
        }'
      """
    end
  end

  defp generate_dynamic_curl_example(name) do
    case name do
      "getblock" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
          {:ok, height} when is_integer(height) and height > 0 ->
            random_height = :rand.uniform(height) - 1
            case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
              {:ok, blockhash} ->
                ~s"""
                curl -X POST http://localhost:18232 \\
                  -H "Content-Type: application/json" \\
                  -d '{
                    "jsonrpc": "2.0",
                    "id": "1",
                    "method": "getblock",
                    "params": ["#{blockhash}"]
                  }'
                """
              _ -> generic_curl(name)
            end
          _ -> generic_curl(name)
        end

      "getrawtransaction" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getrawmempool", []}, 2000) do
          {:ok, mempool} when is_list(mempool) and length(mempool) > 0 ->
            txid = Enum.random(mempool)
            ~s"""
            curl -X POST http://localhost:18232 \\
              -H "Content-Type: application/json" \\
              -d '{
                "jsonrpc": "2.0",
                "id": "1",
                "method": "getrawtransaction",
                "params": ["#{txid}", 1]
              }'
            """
          _ ->
            ~s"""
            curl -X POST http://localhost:18232 \\
              -H "Content-Type: application/json" \\
              -d '{
                "jsonrpc": "2.0",
                "id": "1",
                "method": "getrawtransaction",
                "params": ["<txid>", 1]
              }'
            """
        end

      "getaddresstxids" -> address_example_curl("getaddresstxids")
      "getaddressutxos" -> address_example_curl("getaddressutxos")
      "getaddressbalance" -> address_example_curl("getaddressbalance")

      "getblockhash" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
          {:ok, height} when is_integer(height) and height > 0 ->
            random_height = :rand.uniform(height) - 1
            ~s"""
            curl -X POST http://localhost:18232 \\
              -H "Content-Type: application/json" \\
              -d '{
                "jsonrpc": "2.0",
                "id": "1",
                "method": "getblockhash",
                "params": [#{random_height}]
              }'
            """
          _ -> generic_curl(name)
        end

      "getblockheader" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
          {:ok, height} when is_integer(height) and height > 0 ->
            random_height = :rand.uniform(height) - 1
            case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
              {:ok, blockhash} ->
                ~s"""
                curl -X POST http://localhost:18232 \\
                  -H "Content-Type: application/json" \\
                  -d '{
                    "jsonrpc": "2.0",
                    "id": "1",
                    "method": "getblockheader",
                    "params": ["#{blockhash}"]
                  }'
                """
              _ -> generic_curl(name)
            end
          _ -> generic_curl(name)
        end

      "validateaddress" ->
        ~s"""
        curl -X POST http://localhost:18232 \\
          -H "Content-Type: application/json" \\
          -d '{
            "jsonrpc": "2.0",
            "id": "1",
            "method": "validateaddress",
            "params": ["#{@public_t_address}"]
          }'
        """

      "z_validateaddress" ->
        ~s"""
        curl -X POST http://localhost:18232 \\
          -H "Content-Type: application/json" \\
          -d '{
            "jsonrpc": "2.0",
            "id": "1",
            "method": "z_validateaddress",
            "params": ["#{@public_ua}"]
          }'
        """

      "z_gettreestate" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
          {:ok, height} when is_integer(height) and height > 0 ->
            random_height = :rand.uniform(height) - 1
            case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
              {:ok, blockhash} ->
                ~s"""
                curl -X POST http://localhost:18232 \\
                  -H "Content-Type: application/json" \\
                  -d '{
                    "jsonrpc": "2.0",
                    "id": "1",
                    "method": "z_gettreestate",
                    "params": ["#{blockhash}"]
                  }'
                """
              _ -> generic_curl(name)
            end
          _ -> generic_curl(name)
        end

      "z_listunifiedreceivers" ->
        ~s"""
        curl -X POST http://localhost:18232 \\
          -H "Content-Type: application/json" \\
          -d '{
            "jsonrpc": "2.0",
            "id": "1",
            "method": "z_listunifiedreceivers",
            "params": ["#{@public_ua}"]
          }'
        """

      "z_getsubtreesbyindex" ->
        ~s"""
        curl -X POST http://localhost:18232 \\
          -H "Content-Type: application/json" \\
          -d '{
            "jsonrpc": "2.0",
            "id": "1",
            "method": "z_getsubtreesbyindex",
            "params": ["orchard", 0]
          }'
        """

      "gettxout" ->
        case GenServer.call(Zcashex, {:call_endpoint, "getrawmempool", []}, 2000) do
          {:ok, mempool} when is_list(mempool) and length(mempool) > 0 ->
            txid = Enum.random(mempool)
            ~s"""
            curl -X POST http://localhost:18232 \\
              -H "Content-Type: application/json" \\
              -d '{
                "jsonrpc": "2.0",
                "id": "1",
                "method": "gettxout",
                "params": ["#{txid}", 0]
              }'
            """
          _ ->
            ~s"""
            curl -X POST http://localhost:18232 \\
              -H "Content-Type: application/json" \\
              -d '{
                "jsonrpc": "2.0",
                "id": "1",
                "method": "gettxout",
                "params": ["<txid>", 0]
              }'
            """
        end

      "getpeerinfo" ->
        ~s"""
        curl -X POST http://localhost:18232 \\
          -H "Content-Type: application/json" \\
          -d '{
            "jsonrpc": "2.0",
            "id": "1",
            "method": "getpeerinfo",
            "params": []
          }'
        """

      _ -> generic_curl(name)
    end
  end

  defp address_example_curl(method_name) do
    ~s"""
    curl -X POST http://localhost:18232 \\
      -H "Content-Type: application/json" \\
      -d '{
        "jsonrpc": "2.0",
        "id": "1",
        "method": "#{method_name}",
        "params": [{
          "addresses": ["#{@public_t_address}"]
        }]
      }'
    """
  end

  defp generic_curl(name) do
    ~s"""
    curl -X POST http://localhost:18232 \\
      -H "Content-Type: application/json" \\
      -d '{
        "jsonrpc": "2.0",
        "id": "1",
        "method": "#{name}",
        "params": []
      }'
    """
  end

  # ==================== SAFE LIVE RESULT ====================
  defp get_live_result(name) do
    try do
      cond do
        name in @dangerous_methods ->
          nil

        name in @dynamic_example_methods ->
          get_dynamic_live_result(name)

        true ->
          case GenServer.call(Zcashex, {:call_endpoint, name, []}, 3000) do
            {:ok, result} -> Jason.encode!(result, pretty: true)
            _ -> nil
          end
      end
    rescue
      _ -> nil
    end
  end

  # (all previous get_dynamic_live_result clauses remain unchanged)
  defp get_dynamic_live_result("getrawtransaction") do
    case GenServer.call(Zcashex, {:call_endpoint, "getrawmempool", []}, 2000) do
      {:ok, mempool} when is_list(mempool) and length(mempool) > 0 ->
        txid = Enum.random(mempool)
        case GenServer.call(Zcashex, {:call_endpoint, "getrawtransaction", [txid, 1]}, 3000) do
          {:ok, result} -> Jason.encode!(result, pretty: true)
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_dynamic_live_result("getblock") do
    case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
      {:ok, height} when is_integer(height) and height > 0 ->
        random_height = :rand.uniform(height) - 1
        case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
          {:ok, blockhash} ->
            case GenServer.call(Zcashex, {:call_endpoint, "getblock", [blockhash]}, 3000) do
              {:ok, result} -> Jason.encode!(result, pretty: true)
              _ -> nil
            end
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_dynamic_live_result(method) when method in ["getaddresstxids", "getaddressutxos", "getaddressbalance"] do
    request = [%{"addresses" => [@public_t_address]}]
    case GenServer.call(Zcashex, {:call_endpoint, method, request}, 3000) do
      {:ok, result} -> Jason.encode!(result, pretty: true)
      _ -> nil
    end
  end

  defp get_dynamic_live_result("getblockhash") do
    case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
      {:ok, height} when is_integer(height) and height > 0 ->
        random_height = :rand.uniform(height) - 1
        case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 3000) do
          {:ok, result} -> Jason.encode!(result, pretty: true)
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_dynamic_live_result("getblockheader") do
    case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
      {:ok, height} when is_integer(height) and height > 0 ->
        random_height = :rand.uniform(height) - 1
        case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
          {:ok, blockhash} ->
            case GenServer.call(Zcashex, {:call_endpoint, "getblockheader", [blockhash]}, 3000) do
              {:ok, result} -> Jason.encode!(result, pretty: true)
              _ -> nil
            end
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_dynamic_live_result("validateaddress") do
    case GenServer.call(Zcashex, {:call_endpoint, "validateaddress", [@public_t_address]}, 3000) do
      {:ok, result} -> Jason.encode!(result, pretty: true)
      _ -> nil
    end
  end

  defp get_dynamic_live_result("z_validateaddress") do
    case GenServer.call(Zcashex, {:call_endpoint, "z_validateaddress", [@public_ua]}, 3000) do
      {:ok, result} -> Jason.encode!(result, pretty: true)
      _ -> nil
    end
  end

  defp get_dynamic_live_result("z_gettreestate") do
    case GenServer.call(Zcashex, {:call_endpoint, "getblockcount", []}, 2000) do
      {:ok, height} when is_integer(height) and height > 0 ->
        random_height = :rand.uniform(height) - 1
        case GenServer.call(Zcashex, {:call_endpoint, "getblockhash", [random_height]}, 2000) do
          {:ok, blockhash} ->
            case GenServer.call(Zcashex, {:call_endpoint, "z_gettreestate", [blockhash]}, 3000) do
              {:ok, result} -> Jason.encode!(result, pretty: true)
              _ -> nil
            end
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_dynamic_live_result("z_listunifiedreceivers") do
    case GenServer.call(Zcashex, {:call_endpoint, "z_listunifiedreceivers", [@public_ua]}, 3000) do
      {:ok, result} -> Jason.encode!(result, pretty: true)
      _ -> nil
    end
  end

  defp get_dynamic_live_result("z_getsubtreesbyindex") do
    case GenServer.call(Zcashex, {:call_endpoint, "z_getsubtreesbyindex", ["orchard", 0]}, 3000) do
      {:ok, result} -> Jason.encode!(result, pretty: true)
      _ -> nil
    end
  end

  defp get_dynamic_live_result("gettxout") do
    case GenServer.call(Zcashex, {:call_endpoint, "getrawmempool", []}, 2000) do
      {:ok, mempool} when is_list(mempool) and length(mempool) > 0 ->
        txid = Enum.random(mempool)
        case GenServer.call(Zcashex, {:call_endpoint, "gettxout", [txid, 0]}, 3000) do
          {:ok, result} -> Jason.encode!(result, pretty: true)
          _ -> nil
        end
      _ -> nil
    end
  end

  # NEW: getpeerinfo with IP addresses hidden for privacy
  defp get_dynamic_live_result("getpeerinfo") do
    case GenServer.call(Zcashex, {:call_endpoint, "getpeerinfo", []}, 3000) do
      {:ok, result} when is_list(result) ->
        sanitized = sanitize_getpeerinfo(result)
        Jason.encode!(sanitized, pretty: true)
      _ -> nil
    end
  end

  # Helper that redacts all IP addresses in getpeerinfo output
  defp sanitize_getpeerinfo(peers) when is_list(peers) do
    Enum.map(peers, fn peer ->
      Map.new(peer, fn
        {"addr", _} -> {"addr", "[redacted]"}
        {"addrbind", _} -> {"addrbind", "[redacted]"}
        {"addrlocal", _} -> {"addrlocal", "[redacted]"}
        {key, value} -> {key, value}
      end)
    end)
  end

  defp get_dynamic_live_result(_), do: nil

  # ==================== EVENT HANDLERS ====================
  def handle_event("select_method", %{"name" => name}, socket) do
    method = Enum.find(socket.assigns.methods, &(&1["name"] == name))

    example_curl =
      if name in @dynamic_example_methods do
        generate_dynamic_curl_example(name)
      else
        curl_example(method)
      end

    live_result = get_live_result(name)

    {:noreply,
     assign(socket,
       selected_method: method,
       example_curl: example_curl,
       live_result: live_result
     )}
  end

  def handle_event("search", %{"value" => term}, socket) do
    filtered =
      Enum.filter(socket.assigns.schema["methods"], fn m ->
        String.contains?(String.downcase(m["name"]), String.downcase(term))
      end)

    {:noreply, assign(socket, methods: filtered)}
  end

  # Icon and tag helpers (unchanged)
  defp method_icon(assigns) do
    tags = assigns.tags || []
    icon = cond do
      Enum.any?(tags, &(&1 == "blockchain")) -> "📦"
      Enum.any?(tags, &(&1 == "address"))    -> "🏠"
      Enum.any?(tags, &(&1 == "transaction")) -> "🔄"
      Enum.any?(tags, &(&1 == "mining"))     -> "⛏️"
      Enum.any?(tags, &(&1 == "network"))    -> "🌐"
      Enum.any?(tags, &(&1 == "wallet"))     -> "👛"
      Enum.any?(tags, &(&1 == "control"))    -> "⚙️"
      Enum.any?(tags, &(&1 == "util"))       -> "🔧"
      true                                   -> "📋"
    end
    size_class = if assigns[:size] == "lg", do: "text-4xl", else: "text-2xl"
    ~H"""
    <div class={"w-10 h-10 flex items-center justify-center rounded-2xl bg-gradient-to-br from-indigo-100 to-purple-100 dark:from-indigo-900 dark:to-purple-900 flex-shrink-0 " <> size_class}>
      <%= icon %>
    </div>
    """
  end

  defp method_tags(assigns) do
    ~H"""
    <div class={"flex gap-1.5 flex-wrap " <> if assigns[:large], do: "mb-6", else: ""}>
      <%= for tag <- @tags || [] do %>
        <span class={"inline-flex items-center px-3 py-1 text-xs font-medium rounded-3xl " <> tag_color(tag)}>
          <%= tag %>
        </span>
      <% end %>
    </div>
    """
  end

  defp tag_color(tag) do
    case tag do
      "blockchain" -> "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"
      "address"    -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300"
      "transaction"-> "bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300"
      "mining"     -> "bg-orange-100 text-orange-700 dark:bg-orange-900 dark:text-orange-300"
      "network"    -> "bg-cyan-100 text-cyan-700 dark:bg-cyan-900 dark:text-cyan-300"
      "wallet"     -> "bg-pink-100 text-pink-700 dark:bg-pink-900 dark:text-pink-300"
      "control"    -> "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"
      "util"       -> "bg-amber-100 text-amber-700 dark:bg-amber-900 dark:text-amber-300"
      _            -> "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"
    end
  end
end