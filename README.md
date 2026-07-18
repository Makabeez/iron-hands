# ⛒ Iron Hands

**A personal trading circuit breaker.** Park your stack, set a cooldown, and you
physically cannot pull it out to fund a tilt trade until the timer clears.

Built for the [Spark](https://buildanything.so/hackathons/spark) hackathon on Monad.

---

## The problem (mine)

I trade. Everyone who trades knows the move: you take a loss, and the worst
version of you immediately wants to size back in and win it back *right now*.
That single impulse has blown more funded challenges and accounts than any bad
thesis ever did. Willpower fails exactly when you need it — mid-tilt, at 2am.

## The solution

Iron Hands is a vault you can lock **yourself** out of. The entire product is one
asymmetry, enforced on-chain:

> You can **always** push your unlock time further out.
> You can **never** pull it closer.

There is no owner, no admin, no pause, no upgrade, and no rescue function — not
even the deployer can release your funds early. When you're tilting and you go to
yank your MON, the contract reverts. That revert is the feature.

It's a Ulysses pact as a smart contract: present-you binds future-you, and the
chain refuses to let you untie the knot early.

## How it works

- `deposit()` — put MON in your vault.
- `lock(duration)` — freeze withdrawals for `duration` seconds. Only ever extends.
- `withdraw(amount)` — reverts with `StillLocked` until the cooldown elapses.

No mutable owner state, no `onlyOwner` escape hatch, no `selfdestruct`. ~120 lines,
zero external dependencies.

## Live demo

- **App:** _<paste your Vercel/Netlify URL>_
- **Contract (Monad testnet):** _<paste deployed address>_
- **Explorer:** https://testnet.monadexplorer.com/address/<address>

The demo money-shot: deposit → engage the breaker → try to withdraw → the tx
**reverts on-chain** and you can watch it fail in the explorer. Judges click
withdraw twice; it holds both times.

---

## Run it

Prereqs: [Foundry](https://book.getfoundry.sh/getting-started/installation),
a wallet with testnet MON from https://faucet.monad.xyz.

```bash
# tests (9 passing)
forge test -vv

# deploy to Monad testnet
cp .env.example .env        # then fill in PRIVATE_KEY
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://testnet-rpc.monad.xyz \
  --broadcast

# grab the printed address, paste it into web/index.html (CONTRACT_ADDRESS)
```

Frontend is a single static file — open `web/index.html` locally, or drop the
`web/` folder on Vercel / Netlify / GitHub Pages. No build step.

### Verify (optional)

See the official guide: https://docs.monad.xyz/guides/verify-smart-contract
```bash
forge verify-contract <ADDRESS> src/IronHands.sol:IronHands \
  --chain 10143 --verifier sourcify
```

---

## Network

| | |
|---|---|
| Chain | Monad Testnet |
| Chain ID | 10143 (0x279f) |
| RPC | https://testnet-rpc.monad.xyz |
| Explorer | https://testnet.monadexplorer.com |
| Faucet | https://faucet.monad.xyz |

---

## Submission form — paste-ready

**Name:** Iron Hands

**Description:** A self-custodial vault that lets you lock yourself out of your own
funds. A personal trading circuit breaker to kill revenge-trading.

**Problem:** Revenge-trading after a loss blows more accounts than bad analysis
does. Willpower fails mid-tilt — the exact moment you need it.

**Solution:** Deposit your stack and set a cooldown. The contract lets you extend
a lock but never shorten it, with no admin backdoor, so you literally can't pull
funds to fund a tilt trade until the timer clears. The early-withdraw revert is
the product.

**Category:** Monad Testnet

**Contract address:** _<deployed address>_

---

MIT · built solo by [makabeez](https://github.com/Makabeez)
