# Zcash Explorer — Crosslink

Phoenix LiveView block explorer for Zcash with **Sapling**, **Orchard**, **Ironwood**, and **Crosslink (TFL)** support.

Talks to a local **Zebra** or **zebra-crosslink** node over JSON-RPC.

This branch adds:

- TFL activation status and finality lag
- Finalized tip (linked to the block page)
- Staking Day window with progress bar
- Finalizer roster (stake share + liveness dots)
- Per-finalizer recency detail
- Wallet staking positions (bonded / unbonded)
- **Finality badges** on block and transaction detail pages
- Homepage nav link to `/live/crosslink`

Works against plain Zebra as well (Crosslink fields show as unavailable / empty).

---

## Requirements

- Ubuntu (other Linux is fine with small adjustments)
- A synced **Zebra** or **[zebra-crosslink](https://github.com/ShieldedLabs/crosslink_monolith)** node with RPC enabled
- Git, and about 2 GB free RAM

**Optional:** PostgreSQL (only if you use features that need Ecto; basic browsing works from RPC + cache alone)

### Dependencies note

This explorer uses a fork of [zcashex](https://github.com/dismad/zcashex) with **Ironwood**
support in the transaction schema (`embeds_one :ironwood`).  
`mix.exs` points at:

```elixir
{:zcashex, github: "dismad/zcashex", branch: "main"}
```

---

## Crosslink node RPC

Example `[rpc]` for a feature-net node with cookie auth **disabled**:

```toml
[rpc]
listen_addr = "127.0.0.1:8232"
enable_cookie_auth = false
cookie_dir = "/home/you/.cache/zebra"
```

When cookie auth is enabled, point `ZCASH_RPC_COOKIE_FILE` at the cookie path instead.

### Crosslink RPCs used

| RPC | Purpose |
|-----|---------|
| `is_tfl_activated` | PoW bootstrap vs Crosslink activated (v14) |
| `get_tfl_final_block_height_and_hash` | Finalized tip (height + hash) |
| `get_tfl_block_finality_from_hash` | Block finality badge |
| `get_tfl_tx_finality_from_hash` | Tx finality badge |
| `get_tfl_recency_status` | Finalizer liveness / PoS height |
| `get_tfl_roster_zec` | Active roster + stake (top 12 on v14 feature net) |
| `wallet_staking_positions` | Local wallet bonds |
| `get_wallet_ufvk` | Local wallet UFVK |
| `wallet_spendable_funds` | Spendable / pending / committed zats |
| `getblockchaininfo` | Orchard / value pools |
| `getblockcount` / `getblock` | Heights and block pages |

Helpers live in `lib/zcash_explorer/crosslink.ex`.

**Notes**

- Tip hashes from Crosslink are returned as **byte arrays**; the explorer normalizes them to display-order hex for `/blocks/<hash>` links.
- Roster pubkeys from `get_tfl_roster_zec` are raw hex. Recency and `wallet_staking_positions` use `PubKeyID` display order (byte-reversed). The page joins both forms.
- v14 feature-net parameters: staking period `10368` blocks (~3 days), staking-day window `3456` blocks (~1 day), active roster cap `12`. Commission is 10% of PoS rewards to that active set by weight, 90% to bonds. Bonds outside the active roster do not open a reward bank.
- Before `is_tfl_activated` the feature net is pure PoW. Finality and the roster stay empty until activation.
- `my_height` (PoS height) is only set when the node is participating as a finalizer.
- Staking bonded/unbonded totals, UFVK, and spendable funds are **wallet-local**, not chain-wide. This page does not broadcast `wallet_staking_action`.
- Finality badges are on detail pages only (not the recent-tx list) to avoid RPC storms.

---

## 1. System packages

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  autoconf \
  m4 \
  libncurses-dev \
  libssl-dev \
  git \
  curl \
  unzip \
  inotify-tools
```

---

## 2. Install asdf (Elixir / Erlang / Node)

asdf 0.20 is a Go binary. Do not clone the old v0.15.0 shell script, and do not source `~/.asdf/asdf.sh`.

```bash
cd /tmp
curl -fsSL -o asdf.tar.gz \
  https://github.com/asdf-vm/asdf/releases/download/v0.20.2/asdf-v0.20.2-linux-amd64.tar.gz
tar -xzf asdf.tar.gz
sudo install -m 755 asdf /usr/local/bin/asdf
asdf version
# expect: v0.20.2
```

Add this to `~/.bashrc` (zsh: `~/.zshrc`). Remove any old `source ~/.asdf/asdf.sh` line.

```bash
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
. <(asdf completion bash)
```

Open a new shell, then install the plugins. Versions come from `.tool-versions` (`elixir 1.18.3`, `erlang 27.3.3`, `nodejs 26.10.0`). `asdf set` writes that file. `asdf global` and `asdf local` do not exist in 0.20.

```bash
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf set erlang 27.3.3
asdf set elixir 1.18.3
asdf set nodejs 26.10.0
asdf install
```

Check:

```bash
elixir -v
# expect: Elixir 1.18.3 (compiled with Erlang/OTP 27)
cat "$(asdf where erlang)/releases/27/OTP_VERSION"
# expect: 27.3.3
node -v
# expect: v26.10.0
```

If `node -v` prints another version, nvm is ahead of the asdf shims. `which node` must be under `~/.asdf/shims`.

## 3. Clone the repo (crosslink branch)

```bash
git clone -b crosslink https://github.com/dismad/zcash-explorer.git
cd zcash-explorer
asdf install
```

---

## 4. Create `.env` (required before Mix)

The app is started with **`./dev.sh`**, which loads `.env`.

```bash
nano .env
```

**Minimum for a Crosslink node with cookie auth disabled:**

```bash
SECRET_KEY_BASE=
SIGNING_SALT=

ZCASHD_HOSTNAME=127.0.0.1
ZCASHD_PORT=8232
ZCASH_NETWORK=testnet

# Leave empty when enable_cookie_auth = false
ZCASH_RPC_COOKIE_FILE=
```

Generate secrets:

```bash
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" > .env
echo "SIGNING_SALT=$(openssl rand -base64 48)" >> .env
echo "ZCASHD_HOSTNAME=127.0.0.1" >> .env
echo "ZCASHD_PORT=8232" >> .env
echo "ZCASH_NETWORK=testnet" >> .env
echo "ZCASH_RPC_COOKIE_FILE=" >> .env
```

**With cookie auth enabled**, set the cookie path:

```bash
ZCASH_RPC_COOKIE_FILE=/var/lib/zebrad-rpc/.cookie
# or ~/.cache/zebra/.cookie
```

Find cookies:

```bash
find ~ /var/lib -name ".cookie" 2>/dev/null
```

---

## 5. Install deps and build assets

```bash
mix deps.get
mix compile

cd assets
npm install
npx webpack --mode development
# or: npm run deploy
cd ..
```

Confirm assets exist:

```bash
ls priv/static/js/app.js
# and/or
ls priv/static/assets/
```

---

## 6. Run

```bash
./dev.sh
# or
source .env && mix phx.server
```

Open:

| URL | Description |
|-----|-------------|
| http://localhost:4000 | Home |
| http://localhost:4000/live/crosslink | Crosslink status |
| http://localhost:4000/blocks/:hash | Block detail (+ finality badge) |
| http://localhost:4000/transactions/:txid | Tx detail (+ finality badge) |

Quick RPC smoke test:

```bash
curl -s -X POST http://127.0.0.1:8232 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"is_tfl_activated","params":[]}' | jq
```

In `iex -S mix`:

```elixir
ZcashExplorer.Crosslink.is_activated()
ZcashExplorer.Crosslink.finalized_tip()
ZcashExplorer.Crosslink.roster(:zec)
```

---

## Features

### Crosslink page (`/live/crosslink`)

- Status cards: TFL activated, chain height, finalized tip + lag, Staking Day
- Network panel: PoW height, finalized tip, PoS height, BFT finalizer count
- Pools: Orchard, staking bonded/unbonded, roster stake total
- Collapsible finalizer roster with liveness dots and stake share bars
- Click a finalizer for recency detail
- Collapsible wallet positions (active + withdrawable bonds)
- Collapsible raw `get_tfl_recency_status` dump

### Finality

- Block and transaction detail pages show a **Finality** badge (`Finalized` / `Not yet` / other)
- Block pages accept height or hash; finality always uses the resolved block hash

### Transactions & blocks

- Recent transactions with **Public Input**, **Public Output**, and **Δ Transparent**
  - Δ = fee for pure transparent txs; signed flow for shielding / deshielding
- Block detail: same flow columns, miner **tag** (name/emoji from coinbase) + **address**
- Transaction detail: multi-pool fee, action counts, type + pools, public transfers

### Block Radar

- Live visualization at **`/block-radar`**

### RPC explorer

- Interactive discovery UI at **`/dev/rpc`**

### Main routes

| Path | Description |
|------|-------------|
| `/` | Home |
| `/live/crosslink` | Crosslink / TFL status |
| `/blocks` | Recent blocks |
| `/blocks/:hash` | Block detail |
| `/transactions` | Recent transactions |
| `/transactions/:txid` | Transaction detail |
| `/mempool` | Mempool |
| `/blockchain-info` | Chain metrics |
| `/block-radar` | Block radar |
| `/dev/rpc` | RPC discover |
| `/nodes` | Nodes |
| `/address/:address` | Transparent address |
| `/shielded/:address` | Shielded address |
| `/ua/:address` | Unified address |
| `/live/orchard_pool` | Orchard pool |
| `/live/ironwood_pool` | Ironwood pool |
| `/api/v1/blockchain-info` | JSON chain info |
| `/api/v1/supply` | Supply / valuePools |

Mainnet and testnet (including Crosslink feature nets) supported via `ZCASH_NETWORK`.

---

## Common issues

| Problem | What to try |
|---------|-------------|
| `./dev.sh` warns about missing `.env` | Create `.env` with secrets + RPC settings |
| `SECRET_KEY_BASE` / `SIGNING_SALT` missing | Put both in `.env` **before** starting; use `./dev.sh` or `source .env` |
| RPC connection errors | Node running? Port 8232? Cookie path empty when auth disabled? |
| Tip link → `parse error` / bad URL | Hash must be normalized from byte array; see `Crosslink.normalize_hash/1` |
| Tip link → `block height not in best chain` | Byte order: try with/without `Enum.reverse()` in `normalize_hash` |
| `mix` / `elixir` not found | `source ~/.bashrc` then `asdf current`; prefer `elixir 1.18.3-otp-27` |
| `/js/app.js` 404 | `cd assets && npm install && npx webpack --mode development` |
| Page loads but nothing live-updates | app.js missing or not loaded; check Network tab for `/js/app.js` |
| No CSS / broken layout | Ensure `priv/static/assets/app.css` exists; restart server |
| Empty recent transactions | Wait for cache warmers; confirm RPC works |
| `ecto` / DB errors | Start Postgres + `mix ecto.setup`, or skip DB if unused |
| Finality always `—` | Confirm node is zebra-crosslink and TFL is activated |

---

## Production

Use `MIX_ENV=prod`, new secrets, HTTPS reverse proxy, and a process manager.  
See [Phoenix deployment](https://hexdocs.pm/phoenix/deployment.html).

Build assets for prod:

```bash
cd assets
npm run deploy
cd ..
```

---

## License

Apache License 2.0

Based on the original Nighthawk zcash-explorer. Ironwood, Crosslink/TFL UI, and related work in this fork.
