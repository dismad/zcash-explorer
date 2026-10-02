defmodule ZcashExplorerWeb.MinersLive do
  use Phoenix.LiveView, layout: false

  @windows [144, 288, 576, 1152]
  @default_window 144
  @cache_ms 600_000

  @impl true
  def mount(_params, _session, socket) do
    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "mainnet"
    window = @default_window

    socket =
      assign(socket,
        page_title: "Top miners",
        zcash_network: network,
        windows: @windows,
        window: window,
        scanning: false,
        progress: nil,
        sort_key: :blocks,
        sort_dir: :desc,
        data: cached(window)
      )

    socket =
      if connected?(socket) and is_nil(socket.assigns.data) do
        start_scan(socket, window)
      else
        maybe_historic(socket)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("window", %{"window" => window}, socket) do
    window = parse_window(window)

    socket =
      case cached(window) do
        nil -> start_scan(socket, window)
        data -> maybe_historic(assign(socket, window: window, scanning: false, progress: nil, data: data))
      end

    {:noreply, socket}
  end

  def handle_event("sort", %{"key" => key}, socket) do
    key = parse_sort(key)

    dir =
      if socket.assigns.sort_key == key and socket.assigns.sort_dir == :desc do
        :asc
      else
        :desc
      end

    {:noreply, assign(socket, sort_key: key, sort_dir: dir)}
  end

  def handle_event("rescan", _, socket) do
    Cachex.del(:app_cache, cache_key(socket.assigns.window))
    {:noreply, start_scan(socket, socket.assigns.window)}
  end

  @impl true
  def handle_info({:miner_block, window, height, block, done, total, started}, socket) do
    if socket.assigns.window != window or not socket.assigns.scanning do
      {:noreply, socket}
    else
      acc = ZcashExplorer.Miners.add_block(socket.assigns.acc, height, block)
      elapsed = System.monotonic_time(:millisecond) - started
      progress = %{done: done, total: total, elapsed_ms: elapsed}

      socket = assign(socket, acc: acc, data: ZcashExplorer.Miners.finalize(acc), progress: progress)

      socket =
        if done == total do
          data = ZcashExplorer.Miners.finalize(acc)
          Cachex.put(:app_cache, cache_key(window), %{data: data, at: System.system_time(:millisecond)})
          maybe_historic(assign(socket, scanning: false, data: data))
        else
          socket
        end

      {:noreply, socket}
    end
  end

  def handle_info({:miner_skip, window, done, total, started}, socket) do
    if socket.assigns.window != window or not socket.assigns.scanning do
      {:noreply, socket}
    else
      acc = %{socket.assigns.acc | scanned: socket.assigns.acc.scanned + 1}
      elapsed = System.monotonic_time(:millisecond) - started
      socket = assign(socket, acc: acc, data: ZcashExplorer.Miners.finalize(acc), progress: %{done: done, total: total, elapsed_ms: elapsed})

      socket =
        if done == total do
          data = ZcashExplorer.Miners.finalize(acc)
          Cachex.put(:app_cache, cache_key(window), %{data: data, at: System.system_time(:millisecond)})
          maybe_historic(assign(socket, scanning: false, data: data))
        else
          socket
        end

      {:noreply, socket}
    end
  end

  def handle_info({:miner_historic, window, address, zat}, socket) do
    data = socket.assigns.data

    if socket.assigns.window != window or is_nil(data) do
      {:noreply, socket}
    else
      ranked =
        Enum.map(data.ranked, fn row ->
          if row.address == address, do: Map.put(row, :historic_mined_zat, zat), else: row
        end)

      data = Map.put(data, :ranked, ranked)
      Cachex.put(:app_cache, cache_key(window), %{data: data, at: System.system_time(:millisecond)})
      {:noreply, assign(socket, data: data)}
    end
  end

  def handle_info({:miner_done, window}, socket) do
    if socket.assigns.window == window do
      {:noreply, assign(socket, scanning: false)}
    else
      {:noreply, socket}
    end
  end

  defp start_scan(socket, window) do
    tip =
      case Zcashex.getblockcount() do
        {:ok, n} when is_integer(n) -> n
        _ -> nil
      end

    from = if tip, do: max(tip - window + 1, 1), else: 1
    heights = if tip, do: Enum.to_list(from..tip), else: []
    acc = ZcashExplorer.Miners.empty(tip, from)
    parent = self()
    started = System.monotonic_time(:millisecond)

    if heights != [] do
      Task.start(fn -> scan_heights(parent, window, heights, started) end)
    end

    assign(socket,
      window: window,
      scanning: heights != [],
      acc: acc,
      progress: %{done: 0, total: length(heights), elapsed_ms: 0},
      data: ZcashExplorer.Miners.finalize(acc)
    )
  end

  defp scan_heights(parent, window, heights, started) do
    total = length(heights)

    Enum.with_index(heights, 1)
    |> Enum.each(fn {height, done} ->
      case fetch_block(height) do
        {:ok, block} ->
          send(parent, {:miner_block, window, height, block, done, total, started})

        _ ->
          send(parent, {:miner_skip, window, done, total, started})
      end
    end)

    send(parent, {:miner_done, window})
  end

  defp maybe_historic(socket) do
    data = socket.assigns[:data]

    if connected?(socket) and is_map(data) and is_integer(data[:tip]) do
      pending =
        data.ranked
        |> Enum.filter(fn row ->
          row.address != "shielded-coinbase" and is_nil(Map.get(row, :historic_mined_zat))
        end)
        |> Enum.map(& &1.address)

      if pending != [] do
        parent = self()
        window = socket.assigns.window
        tip = data.tip

        Task.start(fn ->
          Enum.each(pending, fn address ->
            stats = ZcashExplorer.Miners.historic_coinbase(address, tip)
            send(parent, {:miner_historic, window, address, stats})
          end)
        end)
      end
    end

    socket
  end

  defp fetch_block(height) do
    try do
      Zcashex.getblock(Integer.to_string(height), 1)
    catch
      :exit, _ -> {:error, :timeout}
    end
  end

  defp cached(window) do
    case Cachex.get(:app_cache, cache_key(window)) do
      {:ok, %{data: data, at: at}} ->
        if System.system_time(:millisecond) - at < @cache_ms, do: data, else: nil

      _ ->
        nil
    end
  end

  defp cache_key(window), do: "miners:#{window}"

  @sort_keys ~w(address share blocks txs window fees historic historic_blocks)

  defp parse_sort(key) when key in @sort_keys, do: String.to_atom(key)
  defp parse_sort(_), do: :blocks

  defp sorted_miners(data, key, dir) do
    data.ranked
    |> Enum.sort_by(&sort_value(&1, key), sort_dir(dir))
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp sort_dir(:asc), do: &<=/2
  defp sort_dir(_), do: &>=/2

  defp sort_value(row, :address), do: row.address
  defp sort_value(row, :share), do: row.share
  defp sort_value(row, :blocks), do: {row.blocks, row.mined_zat}
  defp sort_value(row, :txs), do: row.txs
  defp sort_value(row, :historic), do: Map.get(row, :historic_mined_zat) || -1
  defp sort_value(row, :historic_blocks), do: Map.get(row, :historic_blocks) || -1
  defp sort_value(row, :window), do: row.mined_zat
  defp sort_value(row, :fees), do: row.fees_zat

  defp sort_mark(key, key, :desc), do: " ↓"
  defp sort_mark(key, key, :asc), do: " ↑"
  defp sort_mark(_, _, _), do: ""

  defp parse_window(window) do
    case Integer.parse(to_string(window)) do
      {n, _} -> if n in @windows, do: n, else: @default_window
      _ -> @default_window
    end
  end

  defp format_zec(n) when is_integer(n) and n > 0 do
    :erlang.float_to_binary(n / 1.0e8, decimals: 4)
  end

  defp format_zec(_), do: "0.0000"

  defp historic_zec(miner) do
    case Map.get(miner, :historic_mined_zat) do
      n when is_integer(n) -> format_zec(n)
      _ -> "…"
    end
  end

  defp historic_blocks(miner) do
    case Map.get(miner, :historic_blocks) do
      n when is_integer(n) -> n
      _ -> "…"
    end
  end

  defp short_addr("shielded-coinbase"), do: "shielded coinbase"

  defp short_addr(addr) when is_binary(addr) and byte_size(addr) > 22 do
    String.slice(addr, 0, 12) <> "…" <> String.slice(addr, -8, 8)
  end

  defp short_addr(addr), do: addr

  defp addr_href("shielded-coinbase"), do: nil
  defp addr_href(addr) when is_binary(addr), do: "/address/#{addr}"
  defp addr_href(_), do: nil

  defp medal(1), do: "bg-amber-400 text-amber-950"
  defp medal(2), do: "bg-slate-300 text-slate-800"
  defp medal(3), do: "bg-orange-400 text-orange-950"
  defp medal(_), do: "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-200"

  defp eta(%{done: done, total: total, elapsed_ms: elapsed}) when done > 0 and total > done do
    remain = round(elapsed / done * (total - done) / 1000)
    "#{remain}s left"
  end

  defp eta(%{done: 0}), do: "one getblock per height"
  defp eta(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title><%= @page_title %></title>
        <link rel="stylesheet" href="/assets/app.css">
        <script defer phx-track-static type="text/javascript" src="/js/app.js"></script>
      </head>
      <body class="bg-slate-100 dark:bg-slate-950 text-slate-900 dark:text-slate-100">
        <header class="bg-gradient-to-r from-indigo-950 via-blue-900 to-cyan-800 text-white">
          <div class="max-w-6xl mx-auto px-4">
            <div class="h-14 flex items-center justify-between">
              <div class="flex items-center gap-x-3">
                <a href="/" class="flex items-center">
                  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
                </a>
                <span class="font-semibold tracking-wide">Top miners</span>
                <span class="text-xs bg-white/15 px-2 py-0.5 rounded"><%= @zcash_network %></span>
              </div>
              <a href="/live/crosslink" class="text-sm hover:underline opacity-90">Crosslink</a>
            </div>
          </div>
        </header>

        <main class="max-w-6xl mx-auto px-4 py-8 space-y-6">
          <div class="flex flex-wrap items-end justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold">Top 100 miners</h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Default sort is blocks in this window, then window ZEC. Click a column to sort.
                Blocks and ZEC mined follow the selected interval. All-time ignores the interval and does not subtract spends.
                <%= if @data && @data.from && @data.tip do %>
                  Heights <%= @data.from %>–<%= @data.tip %>.
                <% end %>
              </p>
            </div>
            <div class="flex items-center gap-2">
              <div class="inline-flex rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden text-xs">
                <%= for window <- @windows do %>
                  <button
                    type="button"
                    phx-click="window"
                    phx-value-window={window}
                    class={"px-3 py-1.5 " <> if(@window == window, do: "bg-blue-600 text-white", else: "bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300")}
                  ><%= window %></button>
                <% end %>
              </div>
              <button type="button" phx-click="rescan" class="text-xs px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-700">
                Rescan
              </button>
            </div>
          </div>

          <%= if @scanning && @progress do %>
            <div class="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4">
              <div class="flex justify-between text-xs text-slate-500 mb-2">
                <span>Scanning blocks</span>
                <span class="tabular-nums">
                  <%= @progress.done %> / <%= @progress.total %>
                  <%= if eta = eta(@progress) do %>
                    · <%= eta %>
                  <% end %>
                </span>
              </div>
              <div class="h-2 rounded-full bg-slate-200 dark:bg-slate-800 overflow-hidden">
                <div
                  class="h-full bg-gradient-to-r from-cyan-400 via-blue-500 to-indigo-500"
                  style={"width: #{if @progress.total > 0, do: @progress.done / @progress.total * 100, else: 0}%"}
                ></div>
              </div>
            </div>
          <% end %>

          <%= if @data do %>
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <div class="rounded-2xl p-4 text-white bg-gradient-to-br from-indigo-600 to-blue-500 shadow-sm">
                <div class="text-xs uppercase tracking-wider text-white/80">Miners</div>
                <div class="mt-1 text-2xl font-bold tabular-nums"><%= length(@data.ranked) %></div>
              </div>
              <div class="rounded-2xl p-4 text-white bg-gradient-to-br from-cyan-600 to-teal-500 shadow-sm">
                <div class="text-xs uppercase tracking-wider text-white/80">Blocks scanned</div>
                <div class="mt-1 text-2xl font-bold tabular-nums"><%= @data.scanned %></div>
              </div>
              <div class="rounded-2xl p-4 text-white bg-gradient-to-br from-amber-500 to-orange-500 shadow-sm">
                <div class="text-xs uppercase tracking-wider text-white/80">Window mined</div>
                <div class="mt-1 text-2xl font-bold tabular-nums"><%= format_zec(@data.total_mined_zat) %></div>
              </div>
              <div class="rounded-2xl p-4 text-white bg-gradient-to-br from-emerald-600 to-lime-500 shadow-sm">
                <div class="text-xs uppercase tracking-wider text-white/80">Fees earned</div>
                <div class="mt-1 text-2xl font-bold tabular-nums"><%= format_zec(@data.total_fees_zat) %></div>
              </div>
            </div>

            <div class="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm">
              <div class="overflow-x-auto">
                <table class="w-full text-sm">
                  <thead class="bg-slate-50 dark:bg-slate-950 text-xs uppercase text-slate-500">
                    <tr>
                      <th class="text-left px-4 py-3 font-medium w-16">#</th>
                      <th class="text-left px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="address" class="uppercase">Address<%= sort_mark(:address, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="share" class="uppercase" title="Share of window coinbase">Share<%= sort_mark(:share, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="blocks" class="uppercase">Blocks mined<%= sort_mark(:blocks, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="txs" class="uppercase">Transactions<%= sort_mark(:txs, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="window" class="uppercase" title="Coinbase paid to this address inside the selected interval.">ZEC mined<%= sort_mark(:window, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="fees" class="uppercase">Fees<%= sort_mark(:fees, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="historic_blocks" class="uppercase" title="Largest coinbase output, height 1 through tip. Same on every interval.">All-time blocks<%= sort_mark(:historic_blocks, @sort_key, @sort_dir) %></button></th>
                      <th class="text-right px-4 py-3 font-medium"><button type="button" phx-click="sort" phx-value-key="historic" class="uppercase" title="All coinbase outputs from height 1 through tip. Spends are not subtracted.">All-time ZEC<%= sort_mark(:historic, @sort_key, @sort_dir) %></button></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
                    <%= for miner <- sorted_miners(@data, @sort_key, @sort_dir) do %>
                      <tr class="hover:bg-slate-50 dark:hover:bg-slate-800/60">
                        <td class="px-4 py-3">
                          <span class={"inline-flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold " <> medal(miner.rank)}>
                            <%= miner.rank %>
                          </span>
                        </td>
                        <td class="px-4 py-3">
                          <div class="flex items-center gap-3 min-w-0">
                            <span class="h-8 w-1.5 rounded-full shrink-0" style={"background: #{miner.color}"}></span>
                            <%= if addr_href(miner.address) do %>
                              <a href={addr_href(miner.address)} class="font-mono text-xs text-blue-600 dark:text-blue-400 hover:underline break-all" title={miner.address}>
                                <%= short_addr(miner.address) %>
                              </a>
                            <% else %>
                              <span class="font-mono text-xs text-slate-500" title={miner.address}><%= short_addr(miner.address) %></span>
                            <% end %>
                          </div>
                        </td>
                        <td class="px-4 py-3">
                          <div class="flex items-center justify-end gap-2">
                            <div class="w-16 h-1.5 rounded-full bg-slate-200 dark:bg-slate-800 overflow-hidden">
                              <div class="h-full rounded-full" style={"width: #{miner.share * 100}%; background: #{miner.color}"}></div>
                            </div>
                            <span class="tabular-nums text-xs w-12 text-right"><%= :erlang.float_to_binary(miner.share * 100, decimals: 1) %>%</span>
                          </div>
                        </td>
                        <td class="px-4 py-3 text-right tabular-nums"><%= miner.blocks %></td>
                        <td class="px-4 py-3 text-right tabular-nums"><%= miner.txs %></td>
                        <td class="px-4 py-3 text-right tabular-nums font-medium"><%= format_zec(miner.mined_zat) %></td>
                        <td class="px-4 py-3 text-right tabular-nums text-emerald-600 dark:text-emerald-400"><%= format_zec(miner.fees_zat) %></td>
                        <td class="px-4 py-3 text-right tabular-nums text-slate-500"><%= historic_blocks(miner) %></td>
                        <td class="px-4 py-3 text-right tabular-nums"><%= historic_zec(miner) %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <%= if @data.ranked == [] and not @scanning do %>
                <p class="p-8 text-center text-slate-500">No coinbase payouts in this window.</p>
              <% end %>
            </div>
            <%= if Map.get(@data, :funding, []) != [] do %>
              <p class="text-xs text-slate-500">
                Coinbase funding outputs, not miners:
                <%= for row <- @data.funding do %>
                  <a href={"/address/#{row.address}"} class="font-mono text-blue-600 dark:text-blue-400 hover:underline" title={row.address}><%= short_addr(row.address) %></a>
                  <%= format_zec(row.mined_zat) %> ZEC
                <% end %>
              </p>
            <% end %>
          <% end %>
        </main>
      </body>
    </html>
    """
  end
end
