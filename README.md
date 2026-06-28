# poseidon-goldilocks

Gas-optimized **Poseidon-Goldilocks** permutation for the EVM (plonky2 compatible).
State = 12 lanes over the Goldilocks field (p = 2^64 − 2^32 + 1), 30 rounds (full×4 → partial×22 → full×4).

`permute([0;12])[0] == 0x3c18a9786cb0b359` — plonky2's official test vector.

## Architecture

### Why this is hard on the EVM

Poseidon-Goldilocks is 30 rounds of field arithmetic over `p = 2^64 − 2^32 + 1`. The EVM has no native
field multiply, so each round is many `mulmod`/`addmod`s — and 30 of them add up fast.

The journey, all measured for one `permute` (see [Gas](#gas), reproduce with the commands there):

1. **Naive plain Solidity** — a direct port of the Python reference (memory `uint256[12]`, a full 12×12
   MDS every round, constants read from a table): **~1,974,000 gas**. Correct, but far too expensive to
   call on-chain.
2. **solc + assembly** — round constants & MDS coefficients inlined as PUSH immediates (no table loads),
   the state held in stack locals and mixed in place (no memory array, no bounds checks), and the 22
   partial rounds using plonky2's fast-partial-round tables instead of a full MDS: **~71,400 gas**
   (~28× cheaper). But the fully-unrolled code no longer fits one EIP-170 (24 KB) contract, so it had to
   be **split into two libraries** — and even then it is still a heavy on-chain operation.
3. **Hand-written Yul** (what ships) — the same algorithm rewritten by hand to shed the remaining
   solc/ABI overhead: **~34,900 gas** (another ~2×).

### What ships

The 30 rounds run as two **hand-written Yul stage contracts** — the only bytecode production ships, each
< EIP-170:

```
Stage1 (yul/Stage1.hex) = full rounds 1–4  +  partial-round init  +  partial rounds 0–10
Stage2 (yul/Stage2.hex) = partial rounds 11–21  +  full rounds 5–8
```

Both expose the same ABI, `run(uint256,uint256,uint256) → (uint256,uint256,uint256)`, with the 12-lane
state packed 4 lanes per word (each lane < 2^64) to keep call marshaling cheap (~0.7 KB/call instead of
~4.1 KB for a `uint256[12]`).

`PoseidonGoldilocks` (`src/PoseidonGoldilocks.sol`) is a thin **Solidity coordinator**: it stores the two
deployed stage addresses as `immutable`s (injected in the constructor) and `permute()` pipelines
`Stage1 → Stage2` by **STATICCALL** (the Yul is pure — reads only calldata, touches no storage — so a
static context is sufficient and safest). On top of `permute()` it offers the fixed-width hash
`hashWithFlag(flag, uint256[8]) → uint256[4]`.

The naive baseline lives in `test/NaiveGas.t.sol` and the solc `PGStage1`/`PGStage2` libraries in
`test/ref/PoseidonRef.sol` (the differential oracle the Yul stages are fuzzed against) — both are kept
for measurement/verification only and are **never deployed**.

## Provenance

Extracted from `pod2_playground/registry-smt-contract` — **only the Poseidon hash part**. The SMT
registry contracts (`Pod2SMT.sol`, `Pod2RegistrySMT.sol`) and their tests, which *used* this hash, were
intentionally left out.

## Layout

| Path | What |
|------|------|
| `src/PoseidonGoldilocks.sol` | **The production contract — Yul only.** Holds the two deployed Yul stage addresses (immutable) and pipelines them by STATICCALL. Exposes `permute(uint256[12])` and the fixed-width `hashWithFlag(flag, uint256[8])`. |
| `src/PoseidonGoldilocksConstants.sol` | Standalone packed-constant tables (plonky2 rev 109d517d), incl. fast-partial-round tables. |
| `yul/Stage1.yul`, `yul/Stage2.yul` | Hand-written Yul re-implementations of the two stages — **the only bytecode production ships**. Build with `yul/build.sh 1` / `yul/build.sh 2` (or `yul/build.sh` for both; committed outputs: `*.hex`). |
| `script/Deploy.s.sol` | Production deploy: reads `yul/Stage{1,2}.hex`, deploys both stages, then `PoseidonGoldilocks` wired to their addresses. |
| `reference/poseidon_reference.py` | Independent (naive-partial-round) Python reference that self-checks against the plonky2 vector. Source of truth for the inlined constants and hash vectors. |
| `test/ref/PoseidonRef.sol` | The original solc `PGStage1` + `PGStage2` libraries — **test oracle only, never deployed.** The differential fuzz tests check the Yul stages against these over random inputs. |
| `test/` | `Poseidon.t.sol` (full permute vs all four official plonky2 vectors), `Hash.t.sol` (`hashWithFlag` vs reference vectors), `YulStage1.t.sol` / `YulStage2.t.sol` (Yul ↔ solc differential + fuzz + size/gas + drift guard). All run against the production Yul config. |

## Usage

`permute` and `hashWithFlag` are `view` (they STATICCALL the stage contracts), so call them on a
deployed `PoseidonGoldilocks` instance:

```solidity
import {PoseidonGoldilocks} from "src/PoseidonGoldilocks.sol";

// `pos` was deployed wired to the two Yul stages (see Deploy).

// Hash 8 field elements -> 4 field elements. `flag` is a domain-separation tag
// mixed into the capacity lanes (use 0 if you don't need domain separation).
uint256[8] memory inputs = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
uint256[4] memory digest = pos.hashWithFlag(0, inputs);

// The raw 12-lane permutation is also exposed.
uint256[12] memory state;                     // all-zero
uint256[12] memory out = pos.permute(state);  // out[0] == 0x3c18a9786cb0b359
```

Inputs are reduced mod p internally, so each lane may be any `uint256`; outputs are canonical Goldilocks
elements (< p). `hashWithFlag` takes exactly 8 inputs and returns the first 4 lanes of the permuted state.

> **About `flag`** — it is just a domain-separation parameter written into the state before the inputs,
> so the same 8 inputs hash to different digests under different flags. The value is yours to choose
> (use `0` if you don't need domain separation); e.g. a Merkle tree might tag leaves and internal nodes
> with distinct flags to keep the two hash kinds from colliding.

## Deploy

`script/Deploy.s.sol` reads the committed `yul/Stage{1,2}.hex`, deploys both stages, then deploys
`PoseidonGoldilocks` wired to their addresses:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url <RPC> --broadcast
# dry-run (local EVM, no broadcast):
forge script script/Deploy.s.sol:Deploy
```

To wire an existing pair of stages, just call the constructor: `new PoseidonGoldilocks(stage1, stage2)`
(both must be already-deployed, non-zero, code-bearing addresses — the constructor asserts this).

## Gas

One `permute`, across the three implementations:

| Implementation | `permute` gas | vs naive | reproduce |
|----------------|---------------|----------|-----------|
| Naive plain Solidity | ~1,974,000 | 1× | `forge test --match-contract NaiveGasTest -vv` |
| solc + assembly | ~71,400 | ~28× cheaper | `forge test --match-test "test_YulStage._Gas\|GasNotWorse" -vv` |
| **Hand-written Yul (shipped)** | **~34,900** | **~57× cheaper** | same command (prints `yul stageN gas`) |

`hashWithFlag` is one `permute` plus call overhead: **~78,000** gas on the solc port vs **~40,800** on the
shipped Yul.

For reference, the EVM-native `keccak256` is a few hundred gas — Poseidon is far heavier on-chain because
the EVM has no native field multiply/`x^7`; the trade-off is that it is cheap *inside* a ZK circuit.
Chaining hashes (e.g. a Merkle proof of depth _d_) costs ≈ _d_ × `hashWithFlag`.

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

## License

[MIT](LICENSE) © 2026 Chaintope Inc. (Yukishige Nakajo &lt;nakajo@chaintope.com&gt;)
