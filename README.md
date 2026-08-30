# Zcash Explorer

Phoenix LiveView block explorer for Zcash with **Sapling**, **Orchard**, and **Ironwood** support.

Talks to a local **Zebra** (or zcashd) node over RPC.

---

## Requirements

- Ubuntu (other Linux is fine with small adjustments)
- A synced Zebra node with RPC enabled
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

git clone https://github.com/dismad/zcash-explorer.git
cd zcash-explorer
asdf install

elixir -v
# expect: Elixir 1.18.3 (compiled with Erlang/OTP 27)
cat "$(asdf where erlang)/releases/27/OTP_VERSION"
# expect: 27.3.3
```

---

## 3. Clone the repo

```bash
git clone https://github.com/dismad/zcash-explorer.git
cd zcash-explorer
asdf install
```

---

## 4. Create `.env` (required before Mix)

The app is started with **`./dev.sh`**, which loads `.env`.

Create the file:

```bash
nano .env
```

**Minimum contents:**

```bash
# Phoenix secrets (required)
SECRET_KEY_BASE=
SIGNING_SALT=

# Zebra RPC cookie (required)
ZCASH_RPC_COOKIE_FILE=/var/lib/zebrad-rpc/.cookie
```

Generate secrets (do this **before** running Mix):

```bash
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" > .env
echo "SIGNING_SALT=$(openssl rand -base64 48)" >> .env
echo "ZCASH_RPC_COOKIE_FILE=/var/lib/zebrad-rpc/.cookie" >> .env
```

Find your cookie if needed:

```bash
find ~ /var/lib -name ".cookie" 2>/dev/null
```

Typical paths:

- `/var/lib/zebrad-rpc/.cookie`
- `~/.cache/zebra/.cookie`

**Optional overrides** (only if different from `config/dev.exs`):

```bash
# ZCASHD_HOSTNAME=localhost
# ZCASHD_PORT=8232
# ZCASH_NETWORK=mainnet
```

For **testnet**, use your testnet cookie/port and set the network in config.

---

## 5. Install dependencies and build assets

```bash
set -a && source .env && set +a
mix deps.get

cd assets
npm install
npx webpack --mode development
cd ..
```

This must create `priv/static/js/app.js`. Check:

```bash
ls -la priv/static/js/app.js
```

Without this file, pages load but **LiveView will not update** (radar, mempool, recent txs stay static).

CSS is built separately to `priv/static/assets/app.css` (Tailwind watcher runs with the Phoenix server).

### Optional: PostgreSQL

Only if you need the database:

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
sudo -u postgres createuser -s $(whoami)
sudo -u postgres createdb zcash_explorer_dev
mix ecto.setup
```

Skip this if basic RPC/cache browsing is enough.

---

## 6. Start the explorer

```bash
chmod +x dev.sh
./dev.sh
```

`dev.sh` loads `.env`, then runs `mix phx.server`.

Open: **http://localhost:4000**

---

## Quick RPC check

```bash
COOKIE="$(tr -d '\n' < "$ZCASH_RPC_COOKIE_FILE")"
curl -s --user "$COOKIE" \
  --data-binary '{"jsonrpc":"2.0","id":1,"method":"getblockcount","params":[]}' \
  -H 'content-type: application/json' \
  "http://127.0.0.1:${ZCASHD_PORT:-8232}/"
```

You should get a block height. Fix Zebra RPC / cookie path before debugging the explorer if this fails.

---

## Features (this fork)

### Shielded pools

- **Sapling**, **Orchard**, and **Ironwood** (NU6.3)
- Pool live views: `/live/orchard_pool`, `/live/ironwood_pool`
- Transaction type badges + pool chips (Transparent / Sapling / Orchard / Ironwood)

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

Mainnet and testnet supported.

---

## Common issues

| Problem | What to try |
|---------|-------------|
| `./dev.sh` warns about missing `.env` | Create `.env` with secrets + `ZCASH_RPC_COOKIE_FILE` |
| `SECRET_KEY_BASE is missing` | Generate with `openssl rand -base64 48` and put in `.env` **before** Mix |
| RPC connection errors | Zebra running? Cookie path correct? Port 8232? |
| `mix` / `elixir` not found | `source ~/.bashrc` then `asdf current` |
| `/js/app.js` 404 | `cd assets && npm install && NODE_OPTIONS=--openssl-legacy-provider npx webpack --mode development` |
| Page loads but nothing live-updates | app.js missing or not loaded; check Network tab for `/js/app.js` |
| No CSS / broken layout | Ensure `priv/static/assets/app.css` exists; restart server |
| Empty recent transactions | Wait for cache warmers; confirm RPC works |
| `ecto` / DB errors | Start Postgres + `mix ecto.setup`, or skip DB if unused |

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

Based on the original Nighthawk zcash-explorer. Ironwood and related UI work in this fork.
