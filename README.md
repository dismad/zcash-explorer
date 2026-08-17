# Zcash Explorer — ZSA

Phoenix LiveView block explorer with experimental **Zcash Shielded Assets (ZSA)** / **V6** support for a private ZSA testnet.

Talks to a local **[Zebra ZSA](https://github.com/zcash-shielded-assets/zebra)** node over JSON-RPC.

This branch adds:

- **V6** / **ZSA** / **Issuance** / **Burn** badges on transaction and block views
- Best-effort **Asset Desc Hash** on detected issuance txs (when the node has no structured ZSA RPC)
- Hex decoder (`ZcashExplorer.ZsaDecoder`) for issuance vs transfer when `issuanceexists` / `getassetstate` are unavailable

---

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Standard Zcash explorer (Sapling / Orchard / Ironwood) |
| `crosslink` | Crosslink / TFL support |
| `zsa` | ZSA / V6 private testnet UI (this branch) |

---

## Requirements

- Ubuntu (other Linux is fine with small adjustments)
- A running **Zebra ZSA** node with RPC enabled (private ZSA testnet)
- Git, and about 2 GB free RAM

**Optional:** PostgreSQL (only if you use Ecto features; basic browsing works from RPC + cache)

### Dependencies note

This branch uses [`dismad/zcashex`](https://github.com/dismad/zcashex) **`zsa`**:

```elixir
{:zcashex, github: "dismad/zcashex", branch: "zsa"}
```

That fork adds `issuanceexists`, `burnexists`, `zip233amount`, and Orchard `flags` (for `enableZSA` when present).

---

## Zebra ZSA RPC

Typical private ZSA testnet config:

```toml
[network]
network = "Testnet"
testnet_variant = "zsa"

[rpc]
listen_addr = "127.0.0.1:18232"
# cookie auth optional; if disabled, leave ZCASH_RPC_COOKIE_FILE empty
```

Cookie path is often under `~/.cache/zebra/` when enabled.

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

(zsh: use `~/.zshrc`)

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

## 3. Clone this branch

```bash
git clone -b zsa https://github.com/dismad/zcash-explorer.git
cd zcash-explorer
asdf install
```

---

## 4. Create `.env` (required before Mix)

The app is started with **`./dev.sh`**, which loads `.env`.

```bash
nano .env
```

**Minimum for a local ZSA node:**

```bash
SECRET_KEY_BASE=
SIGNING_SALT=

ZCASHD_HOSTNAME=127.0.0.1
ZCASHD_PORT=18232
ZCASH_NETWORK=testnet

# Cookie auth enabled:
ZCASH_RPC_COOKIE_FILE=/home/you/.cache/zebra/.cookie

# Cookie auth disabled:
# ZCASH_RPC_COOKIE_FILE=
```

Generate secrets:

```bash
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" > .env
echo "SIGNING_SALT=$(openssl rand -base64 48)" >> .env
echo "ZCASHD_HOSTNAME=127.0.0.1" >> .env
echo "ZCASHD_PORT=18232" >> .env
echo "ZCASH_NETWORK=testnet" >> .env
echo "ZCASH_RPC_COOKIE_FILE=$HOME/.cache/zebra/.cookie" >> .env
```

Find the cookie if needed:

```bash
find ~ /var/lib -name ".cookie" 2>/dev/null
```

---

## 5. Install deps and build assets

```bash
set -a && source .env && set +a
mix deps.get
mix compile

cd assets
npm install
NODE_OPTIONS=--openssl-legacy-provider npx webpack --mode development
cd ..
```

Confirm:

```bash
ls -la priv/static/js/app.js
```

Without `app.js`, pages load but LiveView will not update.

### Optional: PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
sudo -u postgres createuser -s $(whoami)
sudo -u postgres createdb zcash_explorer_dev
mix ecto.setup
```

Skip if RPC/cache-only browsing is enough.

---

## 6. Run

```bash
chmod +x dev.sh
./dev.sh
```

Open **http://localhost:4000**

### Quick RPC check

```bash
COOKIE_FILE="${ZCASH_RPC_COOKIE_FILE:-}"
if [ -n "$COOKIE_FILE" ] && [ -f "$COOKIE_FILE" ]; then
  COOKIE="$(tr -d '\n' < "$COOKIE_FILE")"
  curl -s --user "$COOKIE" \
    --data-binary '{"jsonrpc":"1.0","id":1,"method":"getblockcount","params":[]}' \
    -H 'content-type: application/json' \
    "http://127.0.0.1:${ZCASHD_PORT:-18232}/"
else
  curl -s \
    --data-binary '{"jsonrpc":"1.0","id":1,"method":"getblockcount","params":[]}' \
    -H 'content-type: application/json' \
    "http://127.0.0.1:${ZCASHD_PORT:-18232}/"
fi
```

You should get a block height.

---

## ZSA UI behavior

| Tx type | Expected badges |
|---------|-----------------|
| Issuance | **V6**, **Issuance**, **ZSA** (+ Asset Desc Hash on detail) |
| ZSA transfer | **V6**, **ZSA** |
| Normal coinbase | no ZSA chips |

Detection uses `lib/zcash_explorer/zsa_decoder.ex` when the node does not expose structured ZSA fields.

---

## Limits

- Many Zebra ZSA builds do not implement `getassetstate` or `issuanceexists` / `burnexists` in `getrawtransaction`
- `orchard.actions` may be empty in RPC even for large ZSA txs (action counts show `0`)
- Issuance detection is best-effort from hex heuristics and may need tuning per Zebra/ZSA revision

---

## Main routes

| Path | Description |
|------|-------------|
| `/` | Home |
| `/blocks` | Recent blocks |
| `/blocks/:hash` | Block detail (+ ZSA badges on txs) |
| `/transactions` | Recent transactions |
| `/transactions/:txid` | Transaction detail (+ ZSA badges / Asset Desc Hash) |
| `/mempool` | Mempool |
| `/blockchain-info` | Chain metrics |
| `/block-radar` | Block radar |
| `/dev/rpc` | RPC discover |

---

## Common issues

| Problem | What to try |
|---------|-------------|
| `./dev.sh` warns about missing `.env` | Create `.env` with secrets + RPC settings |
| `SECRET_KEY_BASE is missing` | Generate with `openssl rand -base64 48` **before** Mix |
| RPC connection errors | Zebra running? Port **18232**? Cookie path correct? |
| Wrong network / empty chain | `ZCASH_NETWORK=testnet` and ZSA node `testnet_variant = "zsa"` |
| `mix` / `elixir` not found | `source ~/.bashrc` then `asdf current` |
| `/js/app.js` 404 | Rebuild assets with webpack (step 5) |
| Page loads but nothing live-updates | Missing `app.js`; check Network tab |
| Transfer shows **Issuance** | Update to latest decoder; transfers should be V6+ZSA only |
| No ZSA badges on known V6 tx | Confirm `zcashex` branch is `zsa` and hex is present on the tx |

---

## Related

- Zebra ZSA: https://github.com/zcash-shielded-assets/zebra
- zcashex (`zsa`): https://github.com/dismad/zcashex/tree/zsa
- Explorer `main`: https://github.com/dismad/zcash-explorer
- Explorer `crosslink`: https://github.com/dismad/zcash-explorer/tree/crosslink
