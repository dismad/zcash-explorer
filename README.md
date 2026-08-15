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
| `is_tfl_activated` | TFL on/off |
| `get_tfl_final_block_height_and_hash` | Finalized tip (height + hash) |
| `get_tfl_block_finality_from_hash` | Block finality badge |
| `get_tfl_tx_finality_from_hash` | Tx finality badge |
| `get_tfl_recency_status` | Finalizer liveness / PoS height |
| `get_tfl_roster_zec` | Roster + stake |
| `wallet_staking_positions` | Local wallet bonds |
| `getblockchaininfo` | Orchard / value pools |
| `getblockcount` / `getblock` | Heights and block pages |

Helpers live in `lib/zcash_explorer/crosslink.ex`.

**Notes**

- Tip hashes from Crosslink are returned as **byte arrays**; the explorer normalizes them to display-order hex for `/blocks/<hash>` links.
- `my_height` (PoS height) is only set when the node is participating as a finalizer.
- Staking bonded/unbonded totals are **wallet-local**, not chain-wide.
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

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```

(zsh users: use `~/.zshrc` instead of `~/.bashrc`)

```bash
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs

asdf install erlang 27.3.3
asdf install elixir 1.18.3-otp-27
asdf install nodejs 14.21.3

asdf global erlang 27.3.3
asdf global elixir 1.18.3-otp-27
asdf global nodejs 14.21.3
```

Check:

```bash
elixir -v   # Elixir 1.18.x, OTP 27
node -v     # v14.x
```

---

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
NODE_OPTIONS=--openssl-legacy-provider npx webpack --mode development
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
| `/js/app.js` 404 | `cd assets && npm install && NODE_OPTIONS=--openssl-legacy-provider npx webpack --mode development` |
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
NODE_OPTIONS=--openssl-legacy-provider npm run deploy
cd ..
```

---

## License

Apache License 2.0

Based on the original Nighthawk zcash-explorer. Ironwood, Crosslink/TFL UI, and related work in this fork.
