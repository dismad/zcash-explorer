defmodule ZcashExplorerWeb.BlockRadarLive do
  use Phoenix.LiveView, layout: false

  @tick_interval 1_000
  @refresh_every 5

  @zoom_dense 399
  @zoom_medium 143
  @zoom_tight 47

  @ema_alpha 0.05
  @default_avg_size 12_000.0

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_interval)
    end

    window = @zoom_dense
    target = target_interval()

    chain_tip =
      case Zcashex.getblockcount() do
        {:ok, n} when is_integer(n) -> n
        _ -> nil
      end

    blocks =
      if chain_tip do
        load_blocks_for_tip(chain_tip, [], window)
      else
        get_recent_blocks() |> Enum.take(window + 1)
      end

    rolling = calculate_rolling_avg_size(blocks)
    network_avg = seed_network_avg(blocks, @default_avg_size)

    {:ok,
     socket
     |> assign(:blocks, blocks)
     |> assign(:tip_height, tip_height(blocks) || chain_tip)
     |> assign(:rolling_avg_size, rolling)
     |> assign(:network_avg_size, network_avg)
     |> assign(:color_mode, "network")
     |> assign(:target_interval, target)
     |> assign(:current_time, DateTime.utc_now())
     |> assign(:tick_count, 0)
     |> assign(:zoom_window, window)
     |> assign(:zoom_dense, @zoom_dense)
     |> assign(:zoom_medium, @zoom_medium)
     |> assign(:zoom_tight, @zoom_tight)}
  end

  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, @tick_interval)
    tick_count = socket.assigns.tick_count + 1

    socket =
      if rem(tick_count, @refresh_every) == 0 do
        refresh_blocks(socket)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:current_time, DateTime.utc_now())
     |> assign(:tick_count, tick_count)}
  end

  def handle_event("zoom", %{"level" => level}, socket) do
    window =
      case level do
        "dense" -> @zoom_dense
        "medium" -> @zoom_medium
        "tight" -> @zoom_tight
        _ -> socket.assigns.zoom_window
      end

    chain_tip =
      socket.assigns.tip_height ||
        case Zcashex.getblockcount() do
          {:ok, n} when is_integer(n) -> n
          _ -> nil
        end

    blocks =
      if chain_tip do
        load_blocks_for_tip(chain_tip, socket.assigns.blocks, window)
      else
        socket.assigns.blocks |> Enum.take(window + 1)
      end

    rolling = calculate_rolling_avg_size(blocks)

    {:noreply,
     socket
     |> assign(:zoom_window, window)
     |> assign(:blocks, blocks)
     |> assign(:tip_height, tip_height(blocks) || chain_tip)
     |> assign(:rolling_avg_size, rolling)}
  end

  def handle_event("color_mode", %{"mode" => mode}, socket)
      when mode in ["window", "network"] do
    {:noreply, assign(socket, :color_mode, mode)}
  end

  def handle_event("color_mode", _params, socket), do: {:noreply, socket}

  defp refresh_blocks(socket) do
    chain_tip =
      case Zcashex.getblockcount() do
        {:ok, n} when is_integer(n) -> n
        _ -> nil
      end

    window = socket.assigns.zoom_window || @zoom_dense

    cond do
      is_nil(chain_tip) ->
        socket

      chain_tip == socket.assigns.tip_height ->
        socket

      true ->
        blocks = load_blocks_for_tip(chain_tip, socket.assigns.blocks, window)
        rolling = calculate_rolling_avg_size(blocks)
        network_avg = update_network_avg(socket.assigns.network_avg_size, blocks)

        socket
        |> assign(:blocks, blocks)
        |> assign(:tip_height, tip_height(blocks) || chain_tip)
        |> assign(:rolling_avg_size, rolling)
        |> assign(:network_avg_size, network_avg)
    end
  end

  defp target_interval do
    case Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] do
      "testnet" -> 60.0
      _ -> 75.0
    end
  end

  defp load_blocks_for_tip(chain_tip, previous_blocks, window) do
    known =
      previous_blocks
      |> Enum.reduce(%{}, fn b, acc ->
        h = height_of(b)
        if is_integer(h), do: Map.put(acc, h, b), else: acc
      end)

    known =
      case get_recent_blocks() do
        cached when is_list(cached) ->
          Enum.reduce(cached, known, fn b, acc ->
            h = height_of(b)
            if is_integer(h) and not Map.has_key?(acc, h), do: Map.put(acc, h, b), else: acc
          end)

        _ ->
          known
      end

    start_h = max(chain_tip - window, 0)

    Enum.map(start_h..chain_tip, fn h ->
      case Map.get(known, h) do
        nil -> fetch_block_summary(h)
        b -> b
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&height_of/1, :desc)
  end

  defp height_of(%{"height" => h}) when is_integer(h), do: h
  defp height_of(%{height: h}) when is_integer(h), do: h
  defp height_of(_), do: nil

  defp fetch_block_summary(height) do
    case do_getblock(height) do
      {:ok, block} ->
        summarize_block(height, block)

      _ ->
        case do_getblock(height) do
          {:ok, block} -> summarize_block(height, block)
          _ -> placeholder_block(height)
        end
    end
  end

  defp do_getblock(height) do
    case Zcashex.getblock(height, 1) do
      {:ok, block} when is_map(block) -> {:ok, block}
      other -> other
    end
  end

  defp summarize_block(height, block) do
    %{
      "height" => block["height"] || height,
      "size" => block["size"] || 0,
      "hash" => block["hash"],
      "time" => format_block_time(block["time"]),
      "tx_count" => length(block["tx"] || []),
      "missing" => false
    }
  end

  defp placeholder_block(height) do
    %{
      "height" => height,
      "size" => 0,
      "hash" => nil,
      "time" => "",
      "tx_count" => 0,
      "missing" => true
    }
  end

  defp format_block_time(unix) when is_integer(unix) do
    case DateTime.from_unix(unix) do
      {:ok, dt} -> DateTime.to_iso8601(dt)
      _ -> ""
    end
  end

  defp format_block_time(_), do: ""

  defp tip_height([]), do: nil
  defp tip_height([%{"height" => h} | _]), do: h
  defp tip_height([%{height: h} | _]), do: h
  defp tip_height(_), do: nil

  defp get_recent_blocks do
    case Cachex.get(:app_cache, "block_cache") do
      {:ok, blocks} when is_list(blocks) -> blocks
      _ -> []
    end
  end

  defp missing?(block) when is_map(block), do: block["missing"] == true
  defp missing?(_), do: false

  defp calculate_rolling_avg_size(blocks) do
    present = Enum.reject(blocks, &missing?/1)

    if Enum.empty?(present) do
      @default_avg_size
    else
      sizes = Enum.map(present, &(&1["size"] || 0))
      Enum.sum(sizes) / max(length(sizes), 1)
    end
  end

  defp seed_network_avg(blocks, fallback) do
    if Enum.empty?(blocks), do: fallback, else: calculate_rolling_avg_size(blocks)
  end

  defp update_network_avg(current_avg, blocks) do
    case Enum.find(blocks, fn b -> not missing?(b) end) do
      %{"size" => size} when is_number(size) ->
        @ema_alpha * size + (1.0 - @ema_alpha) * current_avg

      _ ->
        current_avg
    end
  end

  defp baseline_size("window", rolling_avg, _network_avg), do: max(rolling_avg, 1.0)
  defp baseline_size(_mode, _rolling_avg, network_avg), do: max(network_avg, 1.0)

  defp compute_reflectivity(block, previous_block, baseline_size, target_interval) do
    if missing?(block) do
      0.0
    else
      dt = delta_t(block, previous_block)
      throughput = (block["size"] || 0) / dt
      target_throughput = baseline_size / target_interval
      normalized = throughput / max(target_throughput, 0.0001)
      dbz = 15 * :math.log10(max(normalized, 0.001)) + 45
      max(0, min(80, dbz))
    end
  end

  defp delta_t(block, previous_block) do
    max(parse_time(block["time"]) - parse_time(previous_block["time"]), 1.0)
  end

  # IMPORTANT: never use `not block["missing"]` — nil is not a boolean
  defp gap?(block, previous_block, target_interval) do
    if missing?(block) do
      false
    else
      delta_t(block, previous_block) > 2 * target_interval
    end
  end

  defp parse_time(time) when is_binary(time) and time != "" do
    case Timex.parse(time, "{ISO:Extended}") do
      {:ok, dt} -> DateTime.to_unix(dt)
      _ -> 0
    end
  end

  defp parse_time(_), do: 0

  defp normalized_size(block, baseline_size) do
    if missing?(block) do
      0.0
    else
      min(3.0, (block["size"] || 0) / max(baseline_size, 1.0))
    end
  end

  defp dbz_to_color(dbz) do
    cond do
      dbz < 5 -> "#4b0082"
      dbz < 15 -> "#0066cc"
      dbz < 25 -> "#00aaff"
      dbz < 35 -> "#00cc88"
      dbz < 45 -> "#88ee00"
      dbz < 55 -> "#ffee00"
      dbz < 65 -> "#ffbb00"
      dbz < 75 -> "#ff6600"
      true -> "#ff2200"
    end
  end

  defp cell_title(block, prev, reflectivity, base, target_interval) do
    if missing?(block) do
      "Block #{block["height"]} • data unavailable"
    else
      dt = round(delta_t(block, prev))
      kb = round((block["size"] || 0) / 1024)
      txs = block["tx_count"] || 0
      gap = if dt > 2 * target_interval, do: " • long gap", else: ""

      "Block #{block["height"]} • #{txs} txs • #{kb} KB • Δt #{dt}s • " <>
        "#{round(reflectivity)} dBZ • baseline #{round(base)} B#{gap}"
    end
  end

  defp zoom_btn_class(current, level) do
    base = "px-3 py-1 rounded-lg text-xs font-medium border transition"

    if current == level do
      base <> " bg-cyan-600 border-cyan-500 text-white"
    else
      base <> " bg-zinc-900 border-zinc-700 text-zinc-300 hover:border-zinc-500"
    end
  end

  defp mode_btn_class(current, mode) do
    base = "px-3 py-1 rounded-lg text-xs font-medium border transition"

    if current == mode do
      base <> " bg-cyan-600 border-cyan-500 text-white"
    else
      base <> " bg-zinc-900 border-zinc-700 text-zinc-300 hover:border-zinc-500"
    end
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Block Radar • Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
        <script defer phx-track-static type="text/javascript" src="/js/app.js"></script>
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
                   seconds_ago =
                     if latest_time > 0,
                       do: DateTime.to_unix(@current_time) - latest_time,
                       else: 0 %>
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
          <div class="max-w-[1150px] mx-auto">
            <div class="mb-6 flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs text-zinc-500 mr-1">Zoom</span>
                <button type="button" phx-click="zoom" phx-value-level="dense"
                  class={zoom_btn_class(@zoom_window, @zoom_dense)}>
                  Dense (<%= @zoom_dense + 1 %>)
                </button>
                <button type="button" phx-click="zoom" phx-value-level="medium"
                  class={zoom_btn_class(@zoom_window, @zoom_medium)}>
                  Medium (<%= @zoom_medium + 1 %>)
                </button>
                <button type="button" phx-click="zoom" phx-value-level="tight"
                  class={zoom_btn_class(@zoom_window, @zoom_tight)}>
                  Tight (<%= @zoom_tight + 1 %>)
                </button>
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs text-zinc-500 mr-1">Color</span>
                <button type="button" phx-click="color_mode" phx-value-mode="network"
                  class={mode_btn_class(@color_mode, "network")}
                  title="vs slow network baseline — history stays steady">
                  Stable
                </button>
                <button type="button" phx-click="color_mode" phx-value-mode="window"
                  class={mode_btn_class(@color_mode, "window")}
                  title="vs this window’s average — max contrast in view">
                  Relative (contrast)
                </button>
              </div>
            </div>

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
                Color = size ÷ Δt vs baseline (not tx count) • Target interval <%= @target_interval %>s
                • Long gaps get a white border
              </p>
              <p class="text-xs text-zinc-500 mt-1 text-center">
                <%= if @color_mode == "window" do %>
                  Relative: max contrast in this view (colors can shift when the tip or zoom changes)
                <% else %>
                  Stable: slow network baseline (history stays steady as the tip moves)
                <% end %>
              </p>
            </div>

            <div class="flex flex-col lg:flex-row gap-8 items-start justify-center">
              <div class="flex-1 max-w-[980px]">
                <div class="relative bg-zinc-950 border-2 border-zinc-800 rounded-3xl pt-5 pb-3 px-4 shadow-2xl" style="aspect-ratio: 1 / 1;">
                  <div class="absolute inset-0 bg-[repeating-linear-gradient(90deg,#27272a_0,#27272a_1px,transparent_1px,transparent_12px)] opacity-30 pointer-events-none"></div>
                  <div class="absolute inset-0 bg-[repeating-linear-gradient(180deg,#27272a_0,#27272a_1px,transparent_1px,transparent_12px)] opacity-30 pointer-events-none"></div>
                  <div class="grid grid-cols-12 gap-px h-full bg-black/80 rounded-2xl overflow-hidden">
                    <% base = baseline_size(@color_mode, @rolling_avg_size, @network_avg_size) %>
                    <%= for {block, idx} <- Enum.with_index(@blocks) do %>
                      <% prev = Enum.at(@blocks, idx + 1) || block
                         reflectivity = compute_reflectivity(block, prev, base, @target_interval)
                         size_norm = normalized_size(block, base)
                         is_most_recent = idx == 0
                         is_gap = gap?(block, prev, @target_interval)
                         is_missing = missing?(block)
                         bg = if is_missing, do: "#27272a", else: dbz_to_color(reflectivity)
                         ring =
                           cond do
                             is_missing -> "box-shadow: inset 0 0 0 1px #52525b;"
                             is_gap -> "box-shadow: inset 0 0 0 2px rgba(255,255,255,0.85);"
                             true -> "box-shadow: inset 0 0 #{round(4 + size_norm * 8)}px #{bg}44;"
                           end
                         href = if block["hash"], do: "/blocks/#{block["hash"]}", else: "#" %>
                      <a
                        href={href}
                        id={"radar-cell-#{block["height"]}"}
                        class={"relative aspect-square flex items-center justify-center rounded border border-zinc-900/30 transition-all overflow-hidden " <>
                          if(is_missing, do: "opacity-60 cursor-default", else: "hover:brightness-110 hover:ring-1 hover:ring-cyan-400/30")}
                        style={"background-color: #{bg}; #{ring}; transform: scale(#{1.0 + size_norm * 0.08});"}
                        title={cell_title(block, prev, reflectivity, base, @target_interval)}
                      >
                        <span class="absolute top-1.5 left-1.5 text-[9px] font-mono text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.9)] z-10 leading-none">
                          <%= block["height"] %>
                        </span>
                        <%= if is_most_recent and not is_missing do %>
                          <div class="absolute inset-0 bg-gradient-to-r from-transparent via-cyan-300/30 to-transparent animate-[sweep_3s_linear_infinite]"></div>
                        <% end %>
                      </a>
                    <% end %>
                  </div>
                </div>
                <p class="text-center text-xs text-zinc-500 mt-3">
                  Most recent (top-left) → oldest • <%= length(@blocks) %> blocks • Checks every 5s
                </p>
              </div>

              <div class="flex flex-col items-center gap-3">
                <div class="text-xs text-zinc-400 text-center tracking-widest">Rain visualization (Last 25 blocks)</div>
                <div class="flex items-start gap-4">
                  <div class="relative bg-zinc-950 border border-zinc-800 rounded-3xl h-[520px] overflow-hidden shadow-2xl w-20 flex-shrink-0">
                    <div class="absolute inset-0 flex flex-col justify-end items-center gap-3 p-3">
                      <% base = baseline_size(@color_mode, @rolling_avg_size, @network_avg_size) %>
                      <%= for {block, idx} <- Enum.with_index(Enum.take(@blocks, 25)) do %>
                        <% prev = Enum.at(@blocks, idx + 1) || block
                           reflectivity = compute_reflectivity(block, prev, base, @target_interval)
                           size_norm = normalized_size(block, base)
                           delay_ms = rem((block["height"] || 0) * 97, 6000)
                           bg = if missing?(block), do: "#27272a", else: dbz_to_color(reflectivity) %>
                        <div
                          id={"raindrop-#{block["height"]}"}
                          class="raindrop relative flex items-center justify-center text-[8px] font-mono text-white/90 drop-shadow-[0_1px_1px_rgba(0,0,0,0.9)]"
                          style={"width: #{9 + size_norm * 13}px;
                                 height: #{16 + size_norm * 11}px;
                                 background-color: #{bg};
                                 animation-delay: -#{delay_ms}ms;"}
                        >
                          <%= block["height"] %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class="text-[10px] text-zinc-500 leading-tight max-w-[160px]">
                    Color = same dBZ scale as the main grid (size ÷ Δt vs baseline).<br><br>
                    Drop size = relative block size.<br><br>
                    White border on grid cells = long gap (&gt; 2× target interval).
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-12 max-w-[980px]">
              <details open>
                <summary class="cursor-pointer text-lg font-semibold text-zinc-300 mb-4 flex items-center gap-2">
                  <span>How the Block Radar Metric Works</span>
                  <span class="text-xs text-zinc-500">(click to collapse)</span>
                </summary>
                <p class="text-sm text-zinc-400 mb-6">
                  Reflectivity uses <strong>throughput = block size ÷ time since previous block</strong>,
                  normalized to a baseline and mapped with
                  <span class="font-mono">dBZ = 15·log10(normalized) + 45</span>
                  (average ≈ mid-legend).<br><br>
                  <strong>Stable</strong> — slow network EMA baseline (history stays steady).<br>
                  <strong>Relative (contrast)</strong> — average of blocks on screen (max contrast; can shift on tip/zoom).<br>
                  <strong>White cell border</strong> — Δt &gt; 2× target interval (<%= @target_interval %>s on this network).<br>
                  Tx count is shown in the tooltip only; it does not drive color.
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
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">~30</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #00cc88;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 30%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Average block</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">12 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">75 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">160 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">~45</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 60%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Large but slow (neutral)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">150 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">200 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">~47</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 95%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Small but fast (neutral)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">6 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">200 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">~47</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffee00;"></div></td>
                        <td class="px-4 py-3"><div class="w-12 h-2 mx-auto bg-white/30 rounded" style="width: 30%;"></div></td>
                      </tr>
                      <tr class="hover:bg-zinc-900/50">
                        <td class="px-4 py-3 text-zinc-300">Large &amp; fast (strong echo)</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 KB</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">30 s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">1,000 B/s</td>
                        <td class="px-4 py-3 text-right font-mono text-zinc-400">~60</td>
                        <td class="px-4 py-3"><div class="w-8 h-8 mx-auto rounded" style="background-color: #ffbb00;"></div></td>
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
