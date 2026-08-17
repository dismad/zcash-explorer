# Zcash Explorer (ZSA branch)

Phoenix LiveView block explorer with experimental **Zcash Shielded Assets (ZSA)** support for a private ZSA testnet.

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Standard Zcash explorer |
| `crosslink` | Crosslink / related work |
| `zsa` | ZSA / V6 testnet UI (this branch) |

## ZSA features

- **V6 badge** — transaction version 6
- **ZSA badge** — large V6 shielded payload (transfers / ZSA activity)
- **Issuance badge** — best-effort detection of issuance txs from raw hex
- **Asset Desc Hash** — shown on detected issuance txs when the node does not expose structured ZSA RPC fields

Detection uses `ZcashExplorer.ZsaDecoder`, which parses tx hex when Zebra does not return `issuanceexists`, `burnexists`, or `getassetstate`.

## Dependencies

- [`dismad/zcashex`](https://github.com/dismad/zcashex) branch **`zsa`**
  - Adds `issuanceexists`, `burnexists`, `zip233amount`
  - Orchard `flags` map (for `enableZSA` when present)

```elixir
{:zcashex, github: "dismad/zcashex", branch: "zsa"}
```

## Local ZSA testnet

Point the explorer at your Zebra ZSA node (RPC cookie / URL in `.env` or config):

```bash
# example
ZCASH_RPC_COOKIE_FILE=/path/to/zebra/.cookie
# RPC typically 127.0.0.1:18232 for this setup
```

## Dev

```bash
mix deps.get
mix phx.server
```

Open a V6 issuance or transfer tx and confirm badges:

| Tx type | Expected badges |
|---------|-----------------|
| Issuance | V6, Issuance, ZSA (+ Asset Desc Hash) |
| ZSA transfer | V6, ZSA |
| Normal coinbase | (no ZSA chips) |

## Limits

- Zebra build in use does not implement `getassetstate` or structured `issuanceexists` in `getrawtransaction`
- Orchard action counts may show `0` for ZSA txs (RPC returns empty `orchard.actions`)
- Issuance detection is best-effort from hex heuristics and may need tuning per Zebra/ZSA revision

## Related

- Zebra ZSA: https://github.com/zcash-shielded-assets/zebra
- zcashex (zsa): https://github.com/dismad/zcashex/tree/zsa
