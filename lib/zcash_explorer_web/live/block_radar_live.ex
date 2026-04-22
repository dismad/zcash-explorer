defmodule ZcashExplorerWeb.BlockRadarLive do
  use Phoenix.LiveView, layout: false

  @target_interval 75.0
  @tick_interval 1_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@tick_interval, self(), :tick)
    end

    blocks = get_recent_blocks()

    {:ok,
     socket
     |> assign(:blocks, blocks)
     |> assign(:rolling_avg_size, calculate_rolling_avg_size(blocks))
     |> assign(:current_time, DateTime.utc_now())
     |> assign(:version, 0)}
  end

  def handle_info(:tick, socket) do
    {:noreply,
     socket
     |> assign(:current_time, DateTime.utc_now())
     |> update(:version, &(&1 + 1))}
  end

  defp get_recent_blocks do
    case Cachex.get(:app_cache, "block_cache") do
      {:ok, blocks} when is_list(blocks) -> blocks
      _ -> []
    end
  end

  defp calculate_rolling_avg_size(blocks) do
    if Enum.empty?(blocks) do
      12_000.0
    else
      sizes = Enum.map(blocks, & &1["size"])
      Enum.sum(sizes) / length(sizes)
    end
  end

  defp compute_reflectivity(block, previous_block, rolling_avg_size) do
    delta_t = max(parse_time(block["time"]) - parse_time(previous_block["time"]), 1.0)
    throughput = block["size"] / delta_t
    target_throughput = rolling_avg_size / @target_interval
    normalized = throughput / target_throughput
    dbz = 10 * :math.log10(max(normalized, 0.001)) + 25
    max(0, min(80, dbz))
  end

  defp parse_time(time) when is_binary(time) do
    case Timex.parse(time, "{ISO:Extended}") do
      {:ok, dt} -> DateTime.to_unix(dt)
      _ -> 0
    end
  end
  defp parse_time(_), do: 0

  defp normalized_size(block, rolling_avg_size) do
    min(3.0, block["size"] / rolling_avg_size)
  end

  defp dbz_to_color(dbz) do
    cond do
      dbz < 5   -> "#4b0082"
      dbz < 15  -> "#0066cc"
      dbz < 25  -> "#00aaff"
      dbz < 35  -> "#00cc88"
      dbz < 45  -> "#88ee00"
      dbz < 55  -> "#ffee00"
      dbz < 65  -> "#ffbb00"
      dbz < 75  -> "#ff6600"
      true      -> "#ff2200"
    end
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Block Radar • Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
        <script>
          setTimeout(() => { window.location.reload(); }, 15000);
        </script>
      </head>
      <body class="bg-zinc-950 text-white font-mono">
        <header class="bg-zinc-900 border-b border-zinc-800 sticky top-0 z-50">
          <div class="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
            <div class="flex items-center gap-x-3">
              <span class="text-2xl">📡</span>
              <h1 class="text-2xl font-semibold tracking-tighter">Block Radar</h1>
            </div>

            <div class="flex items-center gap-x-3 text-sm">
              <%= if @blocks != [] do %>
                <% latest = List.first(@blocks)
                   latest_time = parse_time(latest["time"])
                   seconds_ago = DateTime.to_unix(@current_time) - latest_time %>
                <div class="flex items-center gap-x-2">
                  <span class="relative flex h-3 w-3">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-3 w-3 bg-emerald-400"></span>
                  </span>
                  <span class="font-medium">Last block • <%= latest["height"] %></span>
                  <span class="text-emerald-400 font-medium"><%= seconds_ago %>s ago</span>
                </div>
              <% else %>
                <span class="text-zinc-400">Waiting for blocks...</span>
              <% end %>
            </div>

            <a href="/" class="text-zinc-400 hover:text-white flex items-center gap-1 text-sm">
              ← Back to Explorer
            </a>
          </div>
        </header>

        <div class="max-w-7xl mx-auto p-6">
          <!-- Centered wrapper for legend + grid/rain + table -->
          <div class="max-w-[1150px] mx-auto">
            <!-- Main dBZ Legend -->
            <div class="mb-8 flex flex-col items-center">
              <div class="w-full h-7 rounded-xl border border-zinc-700 flex overflow-hidden shadow-inner" style="max-width: 980px;">
                <%= for i <- 0..80 do %>
                  <div class="flex-1" style={"background-color: #{dbz_to_color(i)};"}></div>
                <% end %>
              </div>
              <div class="flex justify-between w-full text-[10px] text-zinc-500 mt-1 font-medium" style="max-width: 980px;">
                <span>0</span><span>20</span><span>40</span><span>60</span><span>80 dBZ</span>
              </div>
              <p class="text-xs text-zinc-400 mt-2 text-center">
                Main grid: Recent blocks • Color = throughput reflectivity (bigger + faster = stronger echo)
              </p>
            </div>

            <div class="flex flex-col lg:flex-row gap-8 items-start justify-center">
              <!-- Main Grid -->
              <div class="flex-1 max-w-[980px]">
                <div class="relative bg-zinc-950 border-2 border-zinc-800 rounded-3xl pt-5 pb-3 px-4 shadow-2xl" style="aspect-ratio: 1 / 1;">
                  <div class="absolute inset-0 bg-[repeating-linear-gradient(90deg,#27272a_0,#27272a_1px,transparent_1px,transparent_12px)] opacity-30 pointer-events-none"></div>
                  <div class="absolute inset-0 bg-[repeating-linear-gradient(180deg,#27272a_0,#27272a_1px,transparent_1px,transparent_12px)] opacity-30 pointer-events-none"></div>

                  <div class="grid grid-cols-12 gap-px h-full bg-black/80 rounded-2xl overflow-hidden">
                    <%= for {block, idx} <- Enum.with_index(@blocks) do %>
                      <% prev = Enum.at(@blocks, idx + 1) || block
                         reflectivity = compute_reflectivity(block, prev, @rolling_avg_size)
                         size_norm = normalized_size(block, @rolling_avg_size)
                         is_most_recent = idx == 0 %>

                      <a
                        href={"/blocks/#{block["hash"]}"}
                        class="relative aspect-square flex items-center justify-center rounded border border-zinc-900/30 transition-all hover:brightness-110 hover:ring-1 hover:ring-cyan-400/30 overflow-hidden"
                        style={"background-color: #{dbz_to_color(reflectivity)};
                               box-shadow: inset 0 0 #{round(4 + size_norm * 8)}px #{dbz_to_color(reflectivity)}44;
                               transform: scale(#{1.0 + size_norm * 0.08});"}
                        title={"Block #{block["height"]} • #{block["tx_count"] || length(block["tx"] || [])} txs • #{round(block["size"]/1024)} KB • Δt #{round(max(parse_time(block["time"]) - parse_time(prev["time"]), 1))}s • #{round(reflectivity)} dBZ"}>

                        <span class="absolute top-1.5 left-1.5 text-[9px] font-mono text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.9)] z-10 leading-none"><%= block["height"] %></span>

                        <%= if is_most_recent do %>
                          <div class="absolute inset-0 bg-gradient-to-r from-transparent via-cyan-300/30 to-transparent animate-[sweep_3s_linear_infinite]"></div>
                        <% end %>
                      </a>
                    <% end %>
                  </div>
                </div>
                <p class="text-center text-xs text-zinc-500 mt-3">Most recent (top-left) → oldest • Auto-refreshes every 15s</p>
              </div>

              <!-- Rain Column with description to the right -->
              <div class="flex flex-col items-center gap-3">
                <div class="text-xs text-zinc-400 text-center tracking-widest">Rain visualization (Last 25 blocks)</div>

                <div class="flex items-start gap-4">
                  <div class="relative bg-zinc-950 border border-zinc-800 rounded-3xl h-[520px] overflow-hidden shadow-2xl w-20 flex-shrink-0">
                    <div class="absolute inset-0 flex flex-col justify-end items-center gap-3 p-3">
                      <%= for block <- Enum.take(@blocks, 25) do %>
                        <% prev = Enum.at(@blocks, 1) || block
                           reflectivity = compute_reflectivity(block, prev, @rolling_avg_size)
                           size_norm = normalized_size(block, @rolling_avg_size) %>
                        <div
                          class="raindrop relative flex items-center justify-center text-[8px] font-mono text-white/90 drop-shadow-[0_1px_1px_rgba(0,0,0,0.9)]"
                          style={"width: #{9 + size_norm * 13}px;
                                 height: #{16 + size_norm * 11}px;
                                 background-color: #{dbz_to_color(reflectivity)};
                                 animation-delay: #{rem(:erlang.unique_integer([:positive]), 6000)}ms;"}>
                          <%= block["height"] %>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="text-[10px] text-zinc-500 leading-tight max-w-[160px]">
                    Color = the block's reflectivity (exactly the same dBZ color used in the main grid — brighter/right-side colors mean bigger block + faster next block = stronger echo)<br><br>
                    Size of the drop = relative block size (larger blocks appear as bigger/fatter drops)
                  </div>
                </div>
              </div>
            </div>

            <!-- Table now aligned left with the grid -->
            <div class="mt-12 max-w-[980px]">
              <details open>
                <summary class="cursor-pointer text-lg font-semibold text-zinc-300 mb-4 flex items-center gap-2">
                  <span>How the Block Radar Metric Works</span>
                  <span class="text-xs text-zinc-500">(click to collapse)</span>
                </summary>
                <p class="text-sm text-zinc-400 mb-6">
                  The radar combines two variables into one “reflectivity” value: <strong>throughput = block size ÷ time since previous block</strong>.<br>
                  This is normalized against the network average and mapped to a dBZ-like scale (logarithmic, like real weather radar).
                </p>

                <div class="overflow-x-auto">
                  <table class="w-full text-sm border border-zinc-700 rounded-2xl overflow-hidden">
                    <thead class="bg-zinc-900">
                      <tr>
                        <th class="px-4 py-3 text-left font-medium text-zinc-400">Scenario</th>
                        <th class="px-4 py-3 text-right font-medium text-zinc-400">Block Size</th>
                        <th class="px-4 py-3 text-right font-medium text-zinc-400">Δt</th>
                        <th class="px-4 py-3 text-right font-medium text-zinc-400">Throughput</th>
                        <th class="px-4 py-3 text-right font-medium text-zinc-400">dBZ</th>
                        <th class="px-4 py-3 text-center font-medium text-zinc-400">Color</th>
                        <th class="px-4 py-3 text-center font-medium text-zinc-400">Visual</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-zinc-700">
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Small &amp; slow (weak echo)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">5 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">150 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">33 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">8</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #4b0082;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 30%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Average block</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">12 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">75 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">160 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">35</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #88ee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 60%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Large but slow (neutral)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">150 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">200 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">35</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 95%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Small but fast (neutral)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">6 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">200 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">35</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 30%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Large &amp; fast (strong echo)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">1,000 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">65</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ff6600;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 95%;"></div></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </details>
            </div>
          </div>
        </div>

        <style>
          @keyframes fall { to { transform: translateY(520px); opacity: 0; } }
          .raindrop {
            border-radius: 50% 50% 50% 50% / 70% 70% 30% 30%;
            box-shadow: 0 0 12px currentColor;
            animation: fall 6s linear infinite;
          }
          @keyframes sweep {
            0% { transform: translateX(-150%); }
            100% { transform: translateX(400%); }
          }
        </style>
      </body>
    </html>
    """
  end
end