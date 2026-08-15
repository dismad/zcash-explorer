defmodule ZcashExplorerWeb.CrosslinkLive do
  use Phoenix.LiveView, layout: false

  @refresh_ms 12_000
  @staking_day_length 150
  @staking_window 70

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, @refresh_ms)

    network = Application.get_env(:zcash_explorer, Zcashex, [])[:zcash_network] || "testnet"

    {:ok,
     assign(socket,
       page_title: "Crosslink",
       zcash_network: network,
       show_raw: false,
       show_positions: false,
       show_roster: false,
       selected_finalizer: nil,
       staking_window: @staking_window,
       data: load_data()
     )}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, assign(socket, data: load_data())}
  end

  @impl true
  def handle_event("toggle_raw", _, socket) do
    {:noreply, assign(socket, show_raw: !socket.assigns.show_raw)}
  end

  def handle_event("toggle_roster", _, socket) do
    {:noreply, assign(socket, show_roster: !socket.assigns.show_roster)}
  end

  def handle_event("toggle_positions", _, socket) do
    {:noreply, assign(socket, show_positions: !socket.assigns.show_positions)}
  end

  def handle_event("select_finalizer", %{"key" => key}, socket) do
    selected =
      if socket.assigns.selected_finalizer == key do
        nil
      else
        key
      end

    {:noreply, assign(socket, selected_finalizer: selected)}
  end

  def handle_event("clear_finalizer", _, socket) do
    {:noreply, assign(socket, selected_finalizer: nil)}
  end

  defp load_data do
    height =
      case Zcashex.getblockcount() do
        {:ok, h} when is_integer(h) -> h
        _ -> nil
      end

    tip =
      case ZcashExplorer.Crosslink.finalized_tip() do
        {:ok, t} -> t
        _ -> nil
      end

    roster =
      case ZcashExplorer.Crosslink.roster(:zec) do
        {:ok, list} when is_list(list) ->
          list
          |> Enum.map(&normalize_roster_entry/1)
          |> Enum.sort_by(& &1.stake, :desc)

        _ ->
          []
      end

    orchard =
      case ZcashExplorer.Crosslink.orchard_pool() do
        {:ok, pool} when is_map(pool) -> pool
        _ -> nil
      end

    finalizer_count =
      case ZcashExplorer.Crosslink.finalizer_count() do
        {:ok, n} -> n
        _ -> 0
      end

    pos_height =
      case ZcashExplorer.Crosslink.pos_height() do
        {:ok, h} -> h
        _ -> nil
      end

    staking =
      case ZcashExplorer.Crosslink.staking_totals() do
        {:ok, totals} -> totals
        _ -> %{bonded_zat: 0, unbonded_zat: 0}
      end

    positions =
      case ZcashExplorer.Crosslink.staking_positions() do
        {:ok, pos} when is_map(pos) -> normalize_positions(pos)
        _ -> %{active: [], withdrawable: []}
      end

    recency =
      case ZcashExplorer.Crosslink.recency_status() do
        {:ok, s} -> s
        _ -> nil
      end

    finalizer_status_map = build_finalizer_status_map(recency)

    %{
      activated: ZcashExplorer.Crosslink.is_activated(),
      height: height,
      tip: tip,
      lag: if(height && tip && tip.height, do: height - tip.height, else: nil),
      pos_height: pos_height,
      finalizer_count: finalizer_count,
      staking_day: staking_day_info(height),
      roster: roster,
      total_stake: Enum.reduce(roster, 0.0, fn e, acc -> acc + e.stake end),
      orchard: orchard,
      staking: staking,
      positions: positions,
      recency: recency,
      finalizer_status_map: finalizer_status_map
    }
  end

  defp normalize_positions(%{"active" => active, "withdrawable" => withdrawable}) do
    active_list =
      (active || %{})
      |> Enum.flat_map(fn {finalizer, bonds} ->
        Enum.map(bonds || [], fn bond ->
          %{
            finalizer: finalizer,
            pk: bond["pk"] || bond["bond_key"],
            create_height: bond["create_height"],
            initial_zat: bond["initial_val"] || 0,
            latest_zat: bond["latest_val"] || 0
          }
        end)
      end)
      |> Enum.sort_by(& &1.latest_zat, :desc)

    withdrawable_list =
      (withdrawable || [])
      |> Enum.map(fn bond ->
        %{
          pk: bond["pk"] || bond["bond_key"],
          latest_zat: bond["latest_val"] || bond["value"] || 0
        }
      end)
      |> Enum.sort_by(& &1.latest_zat, :desc)

    %{active: active_list, withdrawable: withdrawable_list}
  end

  defp normalize_positions(_), do: %{active: [], withdrawable: []}

  defp build_finalizer_status_map(%{"finalizer_statuses" => list}) when is_list(list) do
    Enum.reduce(list, %{}, fn
      [key, status], acc when is_binary(key) and is_map(status) ->
        Map.put(acc, key, status)

      {key, status}, acc when is_binary(key) and is_map(status) ->
        Map.put(acc, key, status)

      _, acc ->
        acc
    end)
  end

  defp build_finalizer_status_map(_), do: %{}

  defp normalize_roster_entry(%{"pub_key" => k, "voting_power" => v}) do
    %{key: k, stake: to_float(v)}
  end

  defp normalize_roster_entry([k, v]) do
    %{key: k, stake: to_float(v)}
  end

  defp normalize_roster_entry(other), do: %{key: inspect(other), stake: 0.0}

  defp to_float(v) when is_number(v), do: v * 1.0

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      _ -> 0.0
    end
  end

  defp to_float(_), do: 0.0

  defp staking_day_info(nil), do: nil

  defp staking_day_info(height) do
    offset = rem(height, @staking_day_length)

    if offset < @staking_window do
      %{status: :open, remaining: @staking_window - offset, next_in: nil, offset: offset}
    else
      %{
        status: :closed,
        remaining: nil,
        next_in: @staking_day_length - offset,
        offset: offset
      }
    end
  end

  defp staking_day_pct(%{status: :open, remaining: rem}) do
    max(0, min(100, rem / @staking_window * 100))
  end

  defp staking_day_pct(%{status: :closed, next_in: n}) do
    closed_len = @staking_day_length - @staking_window
    elapsed = closed_len - n
    max(0, min(100, elapsed / closed_len * 100))
  end

  defp staking_day_pct(_), do: 0

  defp format_stake(n) when is_number(n) do
    :erlang.float_to_binary(n * 1.0, decimals: 3)
  end

  defp format_stake(_), do: "—"

  defp format_pool(%{"chainValue" => v}) when is_number(v) do
    :erlang.float_to_binary(v * 1.0, decimals: 3) <> " cTAZ"
  end

  defp format_pool(%{"chainValueZat" => z}) when is_number(z) do
    :erlang.float_to_binary(z / 1.0e8, decimals: 3) <> " cTAZ"
  end

  defp format_pool(_), do: "—"

  defp format_zat(n) when is_number(n) and n > 0 do
    :erlang.float_to_binary(n / 1.0e8, decimals: 3) <> " cTAZ"
  end

  defp format_zat(_), do: "—"

  defp short_key(key) when is_binary(key) and byte_size(key) > 16 do
    String.slice(key, 0, 8) <> "…" <> String.slice(key, -6, 6)
  end

  defp short_key(key), do: key

  # uaMadness-style fingerprint: char frequencies → sorted rainbow bars
  defp hex_fingerprint(key) when is_binary(key) do
    freq =
      key
      |> String.downcase()
      |> String.graphemes()
      |> Enum.frequencies()

    chars = Enum.map(?0..?9, &<<&1>>) ++ Enum.map(?a..?f, &<<&1>>)

    max_count =
      freq
      |> Map.values()
      |> Enum.max(fn -> 1 end)

    Enum.map(chars, fn c ->
      count = Map.get(freq, c, 0)
      pct = if max_count > 0, do: count / max_count * 100, else: 0
      hue = if max_count > 1, do: (count - 1) / (max_count - 1) * 300, else: 180

      %{
        char: c,
        count: count,
        pct: pct,
        color: "hsl(#{Float.round(hue * 1.0, 1)}, 85%, 55%)"
      }
    end)
    |> Enum.filter(&(&1.count > 0))
  end

  defp hex_fingerprint(_), do: []

  defp liveness_dot(nil), do: "bg-gray-400"

  defp liveness_dot(status) when is_map(status) do
    case status["last_direct_connection_utc"] do
      t when is_integer(t) and t > 0 ->
        now = System.system_time(:second)
        age = now - t

        cond do
          age < 120 -> "bg-emerald-500"
          age < 600 -> "bg-amber-500"
          true -> "bg-rose-500"
        end

      _ ->
        "bg-gray-400"
    end
  end

  defp selected_status(data, key) do
    Map.get(data.finalizer_status_map || %{}, key)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Crosslink · Zcash Explorer</title>
        <link rel="stylesheet" href="/assets/app.css">
        <script defer phx-track-static type="text/javascript" src="/js/app.js"></script>
      </head>
      <body class="bg-gray-50 dark:bg-gray-900 min-h-screen text-gray-900 dark:text-gray-100">
        <header class="bg-gradient-to-r from-blue-950 via-blue-900 to-blue-800 text-white sticky top-0 z-50 shadow-md">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="h-14 flex items-center justify-between">
              <div class="flex items-center gap-x-3">
                <a href="/" class="flex items-center">
                  <img src="/images/zcash-icon-white.svg" class="h-8 w-8" alt="Zcash">
                </a>
                <span class="font-semibold tracking-wide">Crosslink</span>
                <span class="text-xs bg-blue-700/60 px-2 py-0.5 rounded"><%= @zcash_network %></span>
              </div>
              <a href="/" class="text-sm hover:underline opacity-90">← Explorer</a>
            </div>
          </div>
        </header>

        <main class="max-w-6xl mx-auto px-4 py-8 space-y-6">
          <h1 class="text-2xl font-bold">Crosslink Status</h1>

          <!-- Status cards -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-4">
              <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">TFL Activated</div>
              <div class="mt-2 text-2xl font-bold">
                <%= case @data.activated do %>
                  <% true -> %><span class="text-emerald-500">Yes</span>
                  <% false -> %><span class="text-rose-500">No</span>
                  <% _ -> %><span class="text-gray-400">—</span>
                <% end %>
              </div>
            </div>

            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-4">
              <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">Chain Height</div>
              <div class="mt-2 text-2xl font-bold tabular-nums"><%= @data.height || "—" %></div>
            </div>

            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-4">
              <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">Finalized Tip</div>
              <div class="mt-2 text-2xl font-bold tabular-nums">
                <%= if @data.tip && @data.tip.hash do %>
                  <a href={"/blocks/#{@data.tip.hash}"} class="text-blue-600 dark:text-blue-400 hover:underline">
                    <%= @data.tip.height %>
                  </a>
                <% else %>
                  <%= if @data.tip, do: @data.tip.height, else: "—" %>
                <% end %>
              </div>
              <%= if @data.lag do %>
                <div class={"mt-1 text-sm font-medium " <> if(@data.lag <= 5, do: "text-emerald-500", else: if(@data.lag <= 20, do: "text-amber-500", else: "text-rose-500"))}>
                  lag <%= @data.lag %> block<%= if @data.lag != 1, do: "s" %>
                </div>
              <% end %>
            </div>

            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-4">
              <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">Staking Day</div>
              <%= if @data.staking_day do %>
                <div class="mt-2 text-2xl font-bold">
                  <%= if @data.staking_day.status == :open do %>
                    <span class="text-emerald-500">Open</span>
                  <% else %>
                    <span class="text-amber-500">Closed</span>
                  <% end %>
                </div>
                <div class="mt-2">
                  <div class="h-2 w-full bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                    <div
                      class={"h-full rounded-full transition-all " <> if(@data.staking_day.status == :open, do: "bg-emerald-500", else: "bg-amber-500")}
                      style={"width: #{staking_day_pct(@data.staking_day)}%"}
                    ></div>
                  </div>
                  <div class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                    <%= if @data.staking_day.status == :open do %>
                      <%= @data.staking_day.remaining %> / <%= @staking_window %> blocks left
                    <% else %>
                      opens in <%= @data.staking_day.next_in %> blocks
                    <% end %>
                  </div>
                </div>
              <% else %>
                <div class="mt-2 text-2xl font-bold text-gray-400">—</div>
              <% end %>
            </div>
          </div>

          <!-- Network + Pools -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-5">
              <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-4">Network</h2>
              <dl class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">PoW Height</dt>
                  <dd class="font-medium tabular-nums"><%= @data.height || "—" %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">PoW Finalized</dt>
                  <dd class="font-medium tabular-nums text-right">
                    <%= if @data.tip && @data.tip.hash do %>
                      <a href={"/blocks/#{@data.tip.hash}"} class="text-blue-600 dark:text-blue-400 hover:underline">
                        <%= @data.tip.height %>
                      </a>
                      <%= if @data.lag do %>
                        <span class={"ml-2 text-xs " <> if(@data.lag <= 5, do: "text-emerald-500", else: "text-amber-500")}>
                          (lag <%= @data.lag %>)
                        </span>
                      <% end %>
                    <% else %>
                      <%= if @data.tip, do: @data.tip.height, else: "—" %>
                    <% end %>
                  </dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">PoS Height</dt>
                  <dd class="font-medium tabular-nums"><%= @data.pos_height || "—" %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">BFT Finalizers</dt>
                  <dd class="font-medium tabular-nums"><%= @data.finalizer_count %></dd>
                </div>
              </dl>
            </div>

            <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-5">
              <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-4">Pools</h2>
              <dl class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">Orchard</dt>
                  <dd class="font-medium tabular-nums">
                    <%= if @data.orchard, do: format_pool(@data.orchard), else: "—" %>
                  </dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">Staking Bonded</dt>
                  <dd class="font-medium tabular-nums"><%= format_zat(@data.staking.bonded_zat) %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">Staking Unbonded</dt>
                  <dd class="font-medium tabular-nums"><%= format_zat(@data.staking.unbonded_zat) %></dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-gray-500 dark:text-gray-400">Roster Stake</dt>
                  <dd class="font-medium tabular-nums"><%= format_stake(@data.total_stake) %> cTAZ</dd>
                </div>
              </dl>
            </div>
          </div>

          <!-- Finalizer detail -->
          <%= if @selected_finalizer do %>
            <% status = selected_status(@data, @selected_finalizer) %>
            <div class="rounded-xl shadow-sm border border-emerald-300 dark:border-emerald-700 bg-white dark:bg-gray-800">
              <button
                phx-click="clear_finalizer"
                class="w-full px-5 py-4 flex items-center justify-between text-left hover:bg-gray-50 dark:hover:bg-gray-700/40 transition"
              >
                <div class="min-w-0 flex items-center gap-3">
                  <div class="flex items-end gap-px shrink-0" style="height: 28px;">
                    <%= for bar <- hex_fingerprint(@selected_finalizer) do %>
                      <div
                        style={"width: 5px; height: #{max(round(bar.pct / 100 * 28), 3)}px; background-color: #{bar.color}; border-radius: 2px 2px 0 0;"}
                      ></div>
                    <% end %>
                  </div>
                  <div class="min-w-0">
                    <span class="font-semibold">Finalizer Detail</span>
                    <span class="ml-2 font-mono text-xs text-gray-500 dark:text-gray-400">
                      <%= short_key(@selected_finalizer) %>
                    </span>
                  </div>
                </div>
                <span class="text-gray-400 text-sm shrink-0">Close ✕</span>
              </button>

              <div class="px-5 pb-5">
                <div class="font-mono text-xs break-all text-gray-600 dark:text-gray-300 mb-3">
                  <%= @selected_finalizer %>
                </div>

                <div class="flex items-end gap-0.5 mb-4" style="height: 48px;">
                  <%= for bar <- hex_fingerprint(@selected_finalizer) do %>
                    <div
                      style={"width: 8px; height: #{max(round(bar.pct / 100 * 48), 4)}px; background-color: #{bar.color}; border-radius: 2px 2px 0 0;"}
                      title={"#{bar.char}: #{bar.count}"}
                    ></div>
                  <% end %>
                </div>

                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                  <div class="flex justify-between sm:block">
                    <dt class="text-gray-500 dark:text-gray-400">Highest round vote</dt>
                    <dd class="font-medium"><%= status && status["highest_round_vote"] || "—" %></dd>
                  </div>
                  <div class="flex justify-between sm:block">
                    <dt class="text-gray-500 dark:text-gray-400">Last direct connection (utc)</dt>
                    <dd class="font-medium tabular-nums">
                      <%= status && status["last_direct_connection_utc"] || "—" %>
                    </dd>
                  </div>
                  <div class="flex justify-between sm:block">
                    <dt class="text-gray-500 dark:text-gray-400">Last seen new info (utc)</dt>
                    <dd class="font-medium tabular-nums">
                      <%= status && status["last_seen_new_info_utc"] || "—" %>
                    </dd>
                  </div>
                  <div class="sm:col-span-2">
                    <dt class="text-gray-500 dark:text-gray-400 mb-1">Votes in my height</dt>
                    <dd class="font-mono text-xs bg-gray-50 dark:bg-gray-900 p-2 rounded overflow-x-auto">
                      <%= inspect(status && status["no_yes_votes_in_my_height"]) %>
                    </dd>
                  </div>
                </dl>
              </div>
            </div>
          <% end %>

          <!-- Roster (collapsible) -->
          <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 overflow-hidden">
            <button
              phx-click="toggle_roster"
              class="w-full px-5 py-4 flex items-center justify-between text-left hover:bg-gray-50 dark:hover:bg-gray-700/40 transition border-b border-gray-200 dark:border-gray-700"
            >
              <span class="font-semibold">
                Finalizer Roster
                <span class="ml-2 text-sm font-normal text-gray-500">
                  (<%= length(@data.roster) %> · <%= format_stake(@data.total_stake) %> cTAZ)
                </span>
              </span>
              <span class="text-gray-400 text-sm">
                <%= if @show_roster, do: "Hide ▲", else: "Show ▼" %>
              </span>
            </button>

            <%= if @show_roster do %>
              <%= if @data.roster == [] do %>
                <div class="p-8 text-center text-gray-500">No roster data</div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead class="bg-gray-50 dark:bg-gray-900/50 text-xs uppercase text-gray-500">
                      <tr>
                        <th class="text-left px-3 sm:px-5 py-3 font-medium w-14">#</th>
                        <th class="text-left px-3 sm:px-5 py-3 font-medium">Finalizer</th>
                        <th class="text-right px-3 sm:px-5 py-3 font-medium whitespace-nowrap">Stake (cTAZ)</th>
                        <th class="text-right px-3 sm:px-5 py-3 font-medium w-28 sm:w-36">Share</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                      <%= for {entry, idx} <- Enum.with_index(@data.roster, 1) do %>
                        <% status = Map.get(@data.finalizer_status_map, entry.key) %>
                        <tr
                          phx-click="select_finalizer"
                          phx-value-key={entry.key}
                          class={"cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/40 " <> if(@selected_finalizer == entry.key, do: "bg-emerald-50 dark:bg-emerald-900/20", else: "")}
                        >
                          <td class="px-3 sm:px-5 py-3 text-gray-400 tabular-nums align-middle whitespace-nowrap">
                            <span class={"inline-block w-2 h-2 rounded-full mr-1.5 " <> liveness_dot(status)}></span>
                            <%= idx %>
                          </td>

                          <td class="px-3 sm:px-5 py-3 align-middle">
                            <div class="flex items-center gap-3 min-w-0">
                              <div
                                class="flex items-end gap-px shrink-0"
                                style="height: 28px;"
                                title={"fingerprint of #{entry.key}"}
                              >
                                <%= for bar <- hex_fingerprint(entry.key) do %>
                                  <div
                                    style={"width: 5px; height: #{max(round(bar.pct / 100 * 28), 3)}px; background-color: #{bar.color}; border-radius: 2px 2px 0 0;"}
                                    title={"#{bar.char}: #{bar.count}"}
                                  ></div>
                                <% end %>
                              </div>
                              <span class="font-mono text-[11px] sm:text-xs text-gray-800 dark:text-gray-200 break-all leading-snug flex-1 text-center">
                                <%= entry.key %>
                              </span>
                            </div>
                          </td>
                          <td class="px-3 sm:px-5 py-3 text-right tabular-nums font-medium align-middle whitespace-nowrap">
                            <%= format_stake(entry.stake) %>
                          </td>

                          <td class="px-3 sm:px-5 py-3 align-middle">
                            <div class="flex items-center justify-end gap-2">
                              <div class="w-14 sm:w-20 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                                <div
                                  class="h-full bg-blue-500 rounded-full"
                                  style={"width: #{if @data.total_stake > 0, do: entry.stake / @data.total_stake * 100, else: 0}%"}
                                ></div>
                              </div>
                              <span class="text-xs text-gray-500 w-10 text-right tabular-nums">
                                <%= if @data.total_stake > 0 do %>
                                  <%= :erlang.float_to_binary(entry.stake / @data.total_stake * 100, decimals: 1) %>%
                                <% else %>
                                  —
                                <% end %>
                              </span>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Wallet positions -->
          <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
            <button
              phx-click="toggle_positions"
              class="w-full px-5 py-4 flex items-center justify-between text-left hover:bg-gray-50 dark:hover:bg-gray-700/40 transition"
            >
              <span class="font-semibold">
                My Positions
                <span class="ml-2 text-sm font-normal text-gray-500">
                  (<%= length(@data.positions.active) %> active ·
                  <%= length(@data.positions.withdrawable) %> withdrawable)
                </span>
              </span>
              <span class="text-gray-400 text-sm">
                <%= if @show_positions, do: "Hide ▲", else: "Show ▼" %>
              </span>
            </button>

            <%= if @show_positions do %>
              <div class="px-5 pb-5 space-y-4">
                <div>
                  <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">Active</h3>
                  <%= if @data.positions.active == [] do %>
                    <p class="text-sm text-gray-400">No active bonds</p>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="w-full text-sm">
                        <thead class="text-xs uppercase text-gray-500">
                          <tr>
                            <th class="text-left py-2 pr-3">Finalizer</th>
                            <th class="text-left py-2 pr-3">Bond pk</th>
                            <th class="text-right py-2 pr-3">Created</th>
                            <th class="text-right py-2 pr-3">Initial</th>
                            <th class="text-right py-2">Latest</th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                          <%= for pos <- @data.positions.active do %>
                            <tr>
                              <td class="py-2 pr-3 font-mono text-xs" title={pos.finalizer}>
                                <%= short_key(pos.finalizer) %>
                              </td>
                              <td class="py-2 pr-3 font-mono text-xs" title={pos.pk}>
                                <%= short_key(pos.pk || "") %>
                              </td>
                              <td class="py-2 pr-3 text-right tabular-nums"><%= pos.create_height || "—" %></td>
                              <td class="py-2 pr-3 text-right tabular-nums"><%= format_zat(pos.initial_zat) %></td>
                              <td class="py-2 text-right tabular-nums font-medium"><%= format_zat(pos.latest_zat) %></td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>

                <div>
                  <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">Withdrawable</h3>
                  <%= if @data.positions.withdrawable == [] do %>
                    <p class="text-sm text-gray-400">None</p>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="w-full text-sm">
                        <thead class="text-xs uppercase text-gray-500">
                          <tr>
                            <th class="text-left py-2 pr-3">Bond pk</th>
                            <th class="text-right py-2">Value</th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                          <%= for pos <- @data.positions.withdrawable do %>
                            <tr>
                              <td class="py-2 pr-3 font-mono text-xs" title={pos.pk}>
                                <%= short_key(pos.pk || "") %>
                              </td>
                              <td class="py-2 text-right tabular-nums font-medium"><%= format_zat(pos.latest_zat) %></td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Collapsible raw -->
          <div class="rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
            <button
              phx-click="toggle_raw"
              class="w-full px-5 py-4 flex items-center justify-between text-left hover:bg-gray-50 dark:hover:bg-gray-700/40 transition"
            >
              <span class="font-semibold">Recency Status (raw)</span>
              <span class="text-gray-400 text-sm">
                <%= if @show_raw, do: "Hide ▲", else: "Show ▼" %>
              </span>
            </button>

            <%= if @show_raw do %>
              <div class="px-5 pb-5">
                <pre class="text-xs overflow-x-auto bg-gray-50 dark:bg-gray-900 p-4 rounded-lg text-gray-700 dark:text-gray-300 max-h-96 overflow-y-auto">
<%= inspect(@data.recency, pretty: true, limit: :infinity) %>
                </pre>
              </div>
            <% end %>
          </div>
        </main>
      </body>
    </html>
    """
  end
end
