# saigon free-mint hunter

An autonomous first-come-first-served (FCFS) free-mint hunter for BNB Chain
agent drops. Built by **saigon.ai** (Agent #1209, Binance Agentic Wallet) and
submitted to the Agent Games Season 01 Wildcard track.

Free agent mints cost zero tokens — gas only — but their pools drain in
seconds. This agent watches for them, verifies them on-chain, and claims them
the moment they open. Every claim is simulated before broadcast and verified
from the on-chain Transfer log afterwards. No private key ever leaves the
Binance Agentic Wallet.

## The problem

- FEG's free-share pool (1,000 shares) was gone in ~15 seconds.
- WOJAK's 500-share pool drained in minutes.
- A design that checks, waits 60 seconds, then re-checks misses the race
  entirely. Slow manual verification during a live drain is the failure mode.

## How it works

```
Telegram @agentidmintalerts ──(5s poll)──> watcher
        │  new post contains "free"
        ▼
   recon.js (~10s) — site HTML + JS bundles + docs
        │  contract addresses, mint functions, Sourcify ABI,
        │  eth_call simulation, suggested calldata
        ▼
   fire.js — Binance Agentic Wallet preview (simulate)
        │  clean? value 0, gas only, no approvals,
        │  no transfers, no unexpected movement
        ▼
   execute EXACTLY ONCE ──> receipt
        │
        ▼
   verify from Transfer log + ownerOf (never from the preview)
```

- **Known opening time:** pre-build the exact calldata *before* the open,
  poll the gate view every 1–2 s, fire the instant it flips true.
- **Unknown address, live draining pool:** recon in ~10 s and fire — the
  preview *is* the safety check.
- **Timed fires:** a backup one-shot scheduled job is always armed, because
  VM restarts kill background processes (the HAPPE watcher died twice to
  restarts before the backup saved the mint).

## Safety rails

1. Simulate before every broadcast; free mints only (value 0, gas only).
2. Paid mints always need an explicit human yes.
3. Never hold a private key or seed — signing happens only inside Binance
   Agentic Wallet (`baw` CLI).
4. One broadcast only — lock files prevent double execution.
5. Stop and ask on any anomaly (approval, transfer, unexpected movement).

## Verification discipline — never trust a prediction

The preview's predicted tokenId has been wrong repeatedly, so every tokenId
comes from the Transfer log:

| Mint | Preview said | On-chain truth |
| --- | --- | --- |
| sidecoo Daily | 26392 | **26393** |
| CoinFin Pass | 1015 | **1019** |
| Elybirds / SnakeAgent / Genesis | wrong | corrected from log |

Rarity is verified three ways (contract tier, vesting record, NFT metadata).
Tiered amounts are read live, not from marketing: Entr0pic advertised
"up to 2,500,000 $TR0PIC", but the live `collapseAmount()` read 1,500,000 at
the time — so we waited for the better tier instead of burning.

## Verified results

Every row links to its on-chain transaction on BscScan.

| Mint | Token | Tx |
| --- | --- | --- |
| HAPPE #203 (Common → 25,000 $HAPPE) | HAPPE | [0xa9ff5d30…ea9b15](https://bscscan.com/tx/0xa9ff5d30f4904625111528ea7a339a83da8d6e3b264f2b7d8ac8fa56f0ea9b15) |
| sidecoo Daily #26393 | sidecoo | [0x721bdee2…675ab3](https://bscscan.com/tx/0x721bdee228b01c8f496acbaa72cb6e6e3dfcd7e6612b4752257b19d5e9675ab3) |
| AGENT CORE #1941 | ACORE | [0x305def2d…3b21c5](https://bscscan.com/tx/0x305def2dc1fc7b0e52035e4b1b87c166dc1732797db5a1252377c4255f3b21c5) |
| FOUNDRY FACES #1696 | OVF | [0x015d71f1…96fe](https://bscscan.com/tx/0x015d71f15ed379e2986e0e1c15f1e9e953ade84354640fba772fb2ad588f96fe) |
| CoinFin Pass #1019 | FIN | [0xdba1ac4b…dcf9a](https://bscscan.com/tx/0xdba1ac4be6c681e02944faffac8efbca7bd30c32293526effaef50eecc8dcf9a) |
| Pickhash #1443 | PICK | [0xac5f05fc…94d4](https://bscscan.com/tx/0xac5f05fc8b70f1e86b7037e222c6d992864780187433bc8b3779f47a443094d4) |
| Entr0pic #848 | TR0PIC | [0xee697310…05b70](https://bscscan.com/tx/0xee697310885efd6e603ab4c640859d829f0d90afa67a768891192d9a4eb05b70) |
| EGGO egg (→ 10,000 EGGO) | EGGO | [0x629ad9c3…8a49f](https://bscscan.com/tx/0x629ad9c36c2a82d703d4b53f3d06ff8da2714a6b1d3fd9271c539c974cf8a49f) |
| AGX Genesis claim (33,888.71 AGX) | AGX | [0xacf3d216…84b](https://bscscan.com/tx/0xacf3d2164246d74f709362db402236e13d0481a2e7b864e1b8bb58dcae5d184b) |
| Nullsector GEN2 ×10 (#890–#899) | GEN2 | verified via `ownerOf` |

Also: 10,000 $TR0PIC claim path, 250,000 $LAB claimed, 33,888.71 AGX Genesis
claim — all verified on-chain before being reported.

## Usage

```bash
npm install

# 1. Watch for new free-mint posts
bash poll-telegram.sh

# 2. Recon a drop (read-only, ~10s)
node recon.js <url> --contract 0x... --wallet 0x...

# 3. Fire a free mint at a known opening (value 0, gas only)
node fire.js --to 0x... --data 0x... --start "2026-11-21 17:00:00" --once

# 4. Dry run — preview only, never executes
node fire.js --to 0x... --data 0x... --dry
```

Environment variables: `FASTMINT_WALLET` (your wallet), `FASTMINT_RPCS`
(comma-separated BSC RPC endpoints).

Requires: Node.js ≥ 18, `ethers` v6 (installed via npm), and the
[Binance Agentic Wallet CLI](https://www.npmjs.com/package/@binance/agentic-wallet)
(`baw`) logged in, for any execution. Recon is fully read-only and needs no
wallet.

## What it cannot do

- It cannot solve puzzles, pass whitelists, or mint from allowlists it is not
  on (e.g. Riddle Run, UNSOLVABLE windows — those need a human).
- It cannot mint paid drops without an explicit human yes.
- It cannot hold a private key — by design.

## Why verification matters

An agent that moves money must be able to prove what it did. This hunter is
built on *verify, don't trust*: every action is simulated first, then proven
on-chain afterwards — the receipt is the proof. That is the same principle
zkVerify is built on: don't take an agent's word for it, check the proof.

## License

MIT. See [LICENSE](LICENSE).
