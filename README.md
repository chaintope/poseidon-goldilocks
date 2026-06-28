# poseidon_hash_contract

Gas-optimized **Poseidon-Goldilocks** permutation for the EVM (POD2 / plonky2 compatible).
State = 12 lanes over the Goldilocks field (p = 2^64 − 2^32 + 1), 30 rounds (full×4 → partial×22 → full×4).

`permute([0;12])[0] == 0x3c18a9786cb0b359` — plonky2's official test vector.

## Provenance

Extracted from `pod2_playground/registry-smt-contract` — **only the Poseidon hash part**. The SMT
registry contracts (`Pod2SMT.sol`, `Pod2RegistrySMT.sol`) and their tests, which *used* this hash, were
intentionally left out.

## Layout

| Path | What |
|------|------|
| `src/PoseidonGoldilocks.sol` | The hash. `PGStage1` + `PGStage2` libraries; `permute()` pipelines them by delegatecall. Round constants & MDS coefficients inlined as PUSH immediates. |
| `src/PoseidonGoldilocksConstants.sol` | Standalone packed-constant tables (plonky2 rev 109d517d), incl. fast-partial-round tables. |
| `yul/Stage1.yul`, `yul/Stage2.yul` | Hand-written Yul re-implementations of the two stages — the bytecode the production deterministic deploy ships. Build with `yul/build.sh 1` / `yul/build.sh 2` (or `yul/build.sh` for both; committed outputs: `*.hex`). |
| `reference/poseidon_reference.py` | Independent (naive-partial-round) Python reference that self-checks against the plonky2 vector. Source of truth for the inlined constants. |
| `test/` | `Poseidon.t.sol` (full permute vs plonky2 vector), `YulStage1.t.sol` / `YulStage2.t.sol` (Yul ↔ solc differential + fuzz + size/gas + drift guard). |

## Build & test

```bash
forge build
forge test -vv
```

The `test_Stage{1,2}HexMatchesYulSource` drift guards recompile the `.yul` and diff against the committed
`.hex`. They need a pinned `solc 0.8.24` at `$HOME/.local/share/svm/0.8.24/solc-0.8.24` (or set `SOLC=`);
otherwise they **skip cleanly** — they never false-fail.

## Dev environment

A Foundry + Claude Code devcontainer lives in `.devcontainer/`. Open in VS Code / Cursor and
"Reopen in Container".
