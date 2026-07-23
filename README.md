# Zcash Explorer 

Phoenix LiveView block explorer for Zcash with **Sapling**, **Orchard**, and **Ironwood** support.

Talks to a local **Zebra** (or zcashd) node over RPC.

---

## Requirements

- Ubuntu (other Linux is fine with small adjustments)
- A synced Zebra node with RPC enabled
- Git, and about 2 GB free RAM

**Optional:** PostgreSQL (only if you use features that need Ecto; basic browsing works from RPC + cache alone)

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
elixir -v    # Elixir 1.18.x, OTP 27
node -v      # v14.x
```

---

## 3. Clone the repo

```bash
git clone https://github.com/dismad/zcash-explorer.git
cd zcash-explorer
asdf install
```

---

## 4. Environment file (`.env`)

The app is started with **`./dev.sh`**, which loads `.env`.

```bash
# create one:
nano .env
```

**Minimum `.env`:**

### Path to your Zebra RPC cookie (required)
```bash
ZCASH_RPC_COOKIE_FILE=/var/lib/zebrad-rpc/.cookie
```
Find the cookie if you’re not sure:

```bash
find ~ /var/lib -name ".cookie" 2>/dev/null
```

Typical paths:

- `/var/lib/zebrad-rpc/.cookie`
- `~/.cache/zebra/.cookie`

### Generate initial secrets without Mix

```bash
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" >> .env
echo "SIGNING_SALT=$(openssl rand -base64 48)" >> .env
echo "ZCASH_RPC_COOKIE_FILE=/path/to/your/.cookie" >> .env
```

### Now Mix works

```bash
mix phx.gen.secret
mix phx.gen.secret
```
Put them in .env

```bash
Bash# Phoenix secrets (required)
SECRET_KEY_BASE=paste_first_secret_here
SIGNING_SALT=paste_second_secret_here
mix deps.get
./dev.sh
```

**Optional overrides** (only if different from defaults in `config/dev.exs`):

```bash
# ZCASHD_HOSTNAME=localhost
# ZCASHD_PORT=8232
# ZCASH_NETWORK=mainnet
```

For **testnet**, use your testnet cookie/port and set the network accordingly in config.

---

## 4. Install dependencies

```bash
mix deps.get
cd assets && npm install && cd ..
```

### Optional: PostgreSQL

Only if you need the database (some setups skip this entirely):

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
sudo -u postgres createuser -s $(whoami)
sudo -u postgres createdb zcash_explorer_dev
mix ecto.setup
```

If the explorer already runs for you without Postgres, you can ignore this section.

---

## 5. Start the explorer

```bash
chmod +x dev.sh
./dev.sh
```

What `dev.sh` does:

1. Loads variables from `.env`
2. Runs `mix phx.server`

Open: **http://localhost:4000**

---

## Quick RPC check

```bash
curl -s --user "$(cat "$ZCASH_RPC_COOKIE_FILE")" \
  --data-binary '{"jsonrpc":"2.0","id":1,"method":"getblockcount","params":[]}' \
  -H 'content-type: application/json' \
  http://127.0.0.1:8232/
```

You should get a block height back. If this fails, fix Zebra RPC / cookie path before debugging the explorer.

---

## Features (this fork)

### Shielded pools
- **Sapling**, **Orchard**, and **Ironwood** (NU6.3)
- Pool value cards and dedicated live views:
  - `/live/orchard_pool`
  - `/live/ironwood_pool`
- Transaction type badges plus pool chips (Transparent / Sapling / Orchard / Ironwood)

### Transactions & blocks
- Recent transactions with **Public Input**, **Public Output**, and **Δ Transparent**
  - Δ shows fee for pure transparent txs, or signed flow for shielding / deshielding
- Block detail pages with the same flow columns, miner **tag** (name/emoji from coinbase) and miner **address**
- Transaction detail: fee (all pools), action counts, type + pools, public transfers

### Block Radar
- Live block visualization at **`/block-radar`**

### RPC explorer
- Interactive RPC discovery UI at **`/dev/rpc`**
- Useful for probing Zebra methods while developing or debugging

### Other routes

| Path | Description |
|------|-------------|
| `/blocks` | Recent blocks |
| `/blocks/:hash` | Block detail |
| `/transactions` | Recent transactions |
| `/transactions/:txid` | Transaction detail |
| `/mempool` | Mempool |
| `/blockchain-info` | Node / chain metrics |
| `/block-radar` | Block radar |
| `/dev/rpc` | RPC discover |
| `/nodes` | Nodes |
| `/address/:address` | Transparent address |
| `/shielded/:address` | Shielded address |
| `/ua/:address` | Unified address |
| `/live/orchard_pool` | Orchard pool value |
| `/live/ironwood_pool` | Ironwood pool value |
| `/api/v1/blockchain-info` | JSON chain info |
| `/api/v1/supply` | Supply / valuePools API |

- Public Input, Public Output, and Δ Transparent on list views
- Miner tag from coinbase (name/emoji) plus address on block pages
- Mainnet and testnet

---

## Common issues

| Problem | What to try |
|---------|-------------|
| `./dev.sh` warns about missing `.env` | Create `.env` with `ZCASH_RPC_COOKIE_FILE=...` |
| RPC connection errors | Zebra running? Correct cookie path? Port 8232 open? |
| `mix` / `elixir` not found | `source ~/.bashrc` then `asdf current` |
| No CSS / broken layout | `cd assets && npm install && cd ..` and restart |
| Empty recent transactions | Wait ~15s for cache warmers; confirm RPC works |
| `ecto` / DB errors | Either start Postgres and run `mix ecto.setup`, or skip DB if you don’t need it |

---

## Production

Use `MIX_ENV=prod`, a real secret key base, HTTPS reverse proxy, and a process manager. See [Phoenix deployment](https://hexdocs.pm/phoenix/deployment.html).

---

## License

Apache License 2.0

Based on the original Nighthawk zcash-explorer. Ironwood and related UI work in this fork.
```

**Summary:** Postgres is optional for basic local use. Rely on `.env` + `./dev.sh` as the normal way to run.
