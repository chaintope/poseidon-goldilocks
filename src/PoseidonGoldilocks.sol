// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Poseidon-Goldilocks permutation (POD2 / plonky2 compatible), gas-optimized for EVM.
///
/// THE HASH. Poseidon over the Goldilocks field (p = 2^64 - 2^32 + 1). State = 12 lanes, each a
/// field element < p. The permutation is 30 rounds applied in this fixed order:
///     full x4  ->  partial x22  ->  full x4
/// where every round is:  (1) AddRoundConstants  (2) S-box x^7  (3) MDS linear mixing.
///   - FULL round:    S-box on all 12 lanes.
///   - PARTIAL round: S-box on lane 0 only (cheaper; security comes from the 8 full rounds).
/// The 360 round constants and the 12x12 MDS matrix come from plonky2 (rev 109d517d). POD2 feeds
/// inputs via hash_with_flag (see Pod2SMT.sol). Output of permute([0;12])[0] == 0x3c18a9786cb0b359
/// (plonky2's official test vector) — asserted in test/Pod2SMT.t.sol.
///
/// LAYOUT. The 30 rounds are split across 2 deployed libraries so each stays < EIP-170 24KB:
///     PGStage1 = full rounds 1-4 + partial-round init + partial rounds 0-10
///     PGStage2 = partial rounds 11-21 + full rounds 5-8
/// permute() pipelines Stage1->Stage2 by delegatecall (3 packed words across the boundary).
///
/// GAS TRICKS (all verified bit-identical to the plonky2 vector):
///   - Round constants & MDS coefficients are inlined as PUSH immediates (no SLOAD/CODECOPY).
///   - State crosses the delegatecall boundary as 3 packed words (4 lanes/word, each < 2^64),
///     not uint256[12]: ABI marshaling drops from ~4.1k to ~0.7k per stage call. See run/_unpack/_pack.
///   - Inside each round the 12 lanes are loaded into stack vars once, all outputs are computed from
///     those (DUP ~3 gas vs mload ~9 gas) and written back IN PLACE — no scratch buffer, no copyback.
///   - Partial-round libs dispatch their 11 round bodies through a function-pointer array + loop, to
///     stop the optimizer re-inlining them into one oversized (>24KB) function.
/// Auto-generated from reference/poseidon_reference.py; do not hand-edit the round bodies.

library PGStage1 {
    uint256 internal constant P = 0xFFFFFFFF00000001;
    /// S-box: x^7 over Goldilocks (x2=x^2, x4=x^4; x^7 = x2*x*x4). Poseidon non-linear step.
    function _sb(uint256 x) private pure returns (uint256) {
        uint256 x2 = mulmod(x, x, P);
        uint256 x4 = mulmod(x2, x2, P);
        return mulmod(mulmod(x2, x, P), x4, P);
    }
    /// MDS linear-mixing layer (Poseidon step 3). Each output lane is the circulant
    /// dot-product of the 12 input lanes with the plonky2 MDS matrix (coeffs 17,15,41,...;
    /// lane 0 also gets the +8 diagonal). Lanes are read into v0..v11 once and outputs are
    /// written in place, so no scratch/copyback is needed.
    function _mds(uint256[12] memory s) private pure {
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let v0 := mload(s)
            let v1 := mload(add(s, 0x20))
            let v2 := mload(add(s, 0x40))
            let v3 := mload(add(s, 0x60))
            let v4 := mload(add(s, 0x80))
            let v5 := mload(add(s, 0xa0))
            let v6 := mload(add(s, 0xc0))
            let v7 := mload(add(s, 0xe0))
            let v8 := mload(add(s, 0x100))
            let v9 := mload(add(s, 0x120))
            let v10 := mload(add(s, 0x140))
            let v11 := mload(add(s, 0x160))
            // --- compute all 12 mixed lanes from v0..v11, write in place ---
            mstore(s, mod(add(add(add(add(add(add(add(add(add(add(add(add(mul(v0, 17), mul(v1, 15)), mul(v2, 41)), mul(v3, 16)), mul(v4, 2)), mul(v5, 28)), mul(v6, 13)), mul(v7, 13)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(v0, 8)), p))
            mstore(add(s, 0x20), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v1, 17), mul(v2, 15)), mul(v3, 41)), mul(v4, 16)), mul(v5, 2)), mul(v6, 28)), mul(v7, 13)), mul(v8, 13)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(v0, 20)), p))
            mstore(add(s, 0x40), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v2, 17), mul(v3, 15)), mul(v4, 41)), mul(v5, 16)), mul(v6, 2)), mul(v7, 28)), mul(v8, 13)), mul(v9, 13)), mul(v10, 39)), mul(v11, 18)), mul(v0, 34)), mul(v1, 20)), p))
            mstore(add(s, 0x60), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v3, 17), mul(v4, 15)), mul(v5, 41)), mul(v6, 16)), mul(v7, 2)), mul(v8, 28)), mul(v9, 13)), mul(v10, 13)), mul(v11, 39)), mul(v0, 18)), mul(v1, 34)), mul(v2, 20)), p))
            mstore(add(s, 0x80), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v4, 17), mul(v5, 15)), mul(v6, 41)), mul(v7, 16)), mul(v8, 2)), mul(v9, 28)), mul(v10, 13)), mul(v11, 13)), mul(v0, 39)), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), p))
            mstore(add(s, 0xa0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v5, 17), mul(v6, 15)), mul(v7, 41)), mul(v8, 16)), mul(v9, 2)), mul(v10, 28)), mul(v11, 13)), mul(v0, 13)), mul(v1, 39)), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), p))
            mstore(add(s, 0xc0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v6, 17), mul(v7, 15)), mul(v8, 41)), mul(v9, 16)), mul(v10, 2)), mul(v11, 28)), mul(v0, 13)), mul(v1, 13)), mul(v2, 39)), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), p))
            mstore(add(s, 0xe0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v7, 17), mul(v8, 15)), mul(v9, 41)), mul(v10, 16)), mul(v11, 2)), mul(v0, 28)), mul(v1, 13)), mul(v2, 13)), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), p))
            mstore(add(s, 0x100), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v8, 17), mul(v9, 15)), mul(v10, 41)), mul(v11, 16)), mul(v0, 2)), mul(v1, 28)), mul(v2, 13)), mul(v3, 13)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), p))
            mstore(add(s, 0x120), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v9, 17), mul(v10, 15)), mul(v11, 41)), mul(v0, 16)), mul(v1, 2)), mul(v2, 28)), mul(v3, 13)), mul(v4, 13)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), p))
            mstore(add(s, 0x140), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v10, 17), mul(v11, 15)), mul(v0, 41)), mul(v1, 16)), mul(v2, 2)), mul(v3, 28)), mul(v4, 13)), mul(v5, 13)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), p))
            mstore(add(s, 0x160), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v11, 17), mul(v0, 15)), mul(v1, 41)), mul(v2, 16)), mul(v3, 2)), mul(v4, 28)), mul(v5, 13)), mul(v6, 13)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), p))
        }
    }
    /// One PARTIAL round (plonky2 "fast partial round"). S-box hits lane 0 only; the other
    /// 11 lanes are mixed by a cheap rank-1 update instead of a full MDS:
    ///   s0          = S-box(lane0) + round constant
    ///   new lane 0  = 25*s0 + dot(lanes 1..11, w_hat[])
    ///   new lane j  = lane j + s0 * v[j]      (j = 1..11)
    /// _pr1.._pr21 are identical in shape, only the constants differ.
    function _pr0(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 8415871462856204715, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 4438751076270498736))
            d := add(d, mul(mload(add(s, 0x40)), 9317528645525775657))
            d := add(d, mul(mload(add(s, 0x60)), 2603614750616077704))
            d := add(d, mul(mload(add(s, 0x80)), 9834445229934519080))
            d := add(d, mul(mload(add(s, 0xa0)), 11955300617986087719))
            d := add(d, mul(mload(add(s, 0xc0)), 13674383287779636394))
            d := add(d, mul(mload(add(s, 0xe0)), 7242667852302110551))
            d := add(d, mul(mload(add(s, 0x100)), 703710881370165964))
            d := add(d, mul(mload(add(s, 0x120)), 5061939192123688976))
            d := add(d, mul(mload(add(s, 0x140)), 14416184509556335938))
            d := add(d, mul(mload(add(s, 0x160)), 304868360577598380))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 10702656082108580291), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 14323272843908492221), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 15449530374849795087), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 839422581341380592), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 11044529172588201887), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 9218907426627144627), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 16863852725141286670), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 12378944184369265821), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 4291107264489923137), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 18105902022777689401), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 4532874245444204412), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr1(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 15156192896528938595, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 7437226027186543243))
            d := add(d, mul(mload(add(s, 0x40)), 15353050892319980048))
            d := add(d, mul(mload(add(s, 0x60)), 3199984117275729523))
            d := add(d, mul(mload(add(s, 0x80)), 11990763268329609629))
            d := add(d, mul(mload(add(s, 0xa0)), 5577680852675862792))
            d := add(d, mul(mload(add(s, 0xc0)), 17892201254274048377))
            d := add(d, mul(mload(add(s, 0xe0)), 4681998189446302081))
            d := add(d, mul(mload(add(s, 0x100)), 6822112447852802370))
            d := add(d, mul(mload(add(s, 0x120)), 7318824523402736059))
            d := add(d, mul(mload(add(s, 0x140)), 63486289239724471))
            d := add(d, mul(mload(add(s, 0x160)), 9953444262837494154))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 783331064993138470), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 11780280264626300249), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 14317347280917240576), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 7639896796391275580), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 5524721098652169327), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 4647621086109661393), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 551557749415629519), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 4774730083352601242), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 9878226461889807280), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 2796688701546052437), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 3152254583822593203), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr2(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 7115538620563575164, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 2317103059171007623))
            d := add(d, mul(mload(add(s, 0x40)), 16480286982765085951))
            d := add(d, mul(mload(add(s, 0x60)), 13705213611198486247))
            d := add(d, mul(mload(add(s, 0x80)), 10236515677047503770))
            d := add(d, mul(mload(add(s, 0xa0)), 6341681382391377123))
            d := add(d, mul(mload(add(s, 0xc0)), 6362787076607341484))
            d := add(d, mul(mload(add(s, 0xe0)), 10057473295910894055))
            d := add(d, mul(mload(add(s, 0x100)), 12586789805515730111))
            d := add(d, mul(mload(add(s, 0x120)), 4352300357074435274))
            d := add(d, mul(mload(add(s, 0x140)), 15739906440350539774))
            d := add(d, mul(mload(add(s, 0x160)), 16786966705537008710))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 5195684422952000615), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 16386310079584461432), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 8354845848262314988), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 6700373425673846218), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 14613275276996917774), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 15810393896142816349), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 8919907675614209581), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 4378937399360000942), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 3921314266986613083), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 3157453341478075556), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 12056705871081879759), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr3(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 15396535437187948468, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 14247238213840877673))
            d := add(d, mul(mload(add(s, 0x40)), 4982197628621364471))
            d := add(d, mul(mload(add(s, 0x60)), 1650209613801527344))
            d := add(d, mul(mload(add(s, 0x80)), 16334009413005742380))
            d := add(d, mul(mload(add(s, 0xa0)), 320004518447392347))
            d := add(d, mul(mload(add(s, 0xc0)), 7777559975827687149))
            d := add(d, mul(mload(add(s, 0xe0)), 1266186313330142639))
            d := add(d, mul(mload(add(s, 0x100)), 12735743610080455214))
            d := add(d, mul(mload(add(s, 0x120)), 9621059894918028247))
            d := add(d, mul(mload(add(s, 0x140)), 4350447204024668858))
            d := add(d, mul(mload(add(s, 0x160)), 11420240845800225374))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 12838957912943317144), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 11392036161259909092), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 5420611346845318460), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 11418874531271499277), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 14582096517505941837), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 877280106856758747), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 11091271673331452926), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 9617340340155417663), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 9043411348035541157), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 16964047224456307403), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 10338102439110648229), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr4(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 13402196712199986140, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 1701204778899409548))
            d := add(d, mul(mload(add(s, 0x40)), 12463216732586668885))
            d := add(d, mul(mload(add(s, 0x60)), 7392209094895994703))
            d := add(d, mul(mload(add(s, 0x80)), 15680934805691729401))
            d := add(d, mul(mload(add(s, 0xa0)), 14004357016008534075))
            d := add(d, mul(mload(add(s, 0xc0)), 14936251243935649556))
            d := add(d, mul(mload(add(s, 0xe0)), 1522896783411827638))
            d := add(d, mul(mload(add(s, 0x100)), 13858466054557097275))
            d := add(d, mul(mload(add(s, 0x120)), 3172936841377972450))
            d := add(d, mul(mload(add(s, 0x140)), 1068421630679369146))
            d := add(d, mul(mload(add(s, 0x160)), 14424837255543781072))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 1277502887239453738), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 11492475458589769996), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 12115111105137538533), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 6007394463725400498), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 4633777909023327008), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 12045217224929432404), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 5600645681481758769), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 13058511211226185597), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 10831228388201534917), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 10765285645335338967), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 12314041551985486068), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr5(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 16375052485106733288, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 10714170731680699852))
            d := add(d, mul(mload(add(s, 0x40)), 5765613494791770423))
            d := add(d, mul(mload(add(s, 0x60)), 9663820292401160995))
            d := add(d, mul(mload(add(s, 0x80)), 397172480378586284))
            d := add(d, mul(mload(add(s, 0xa0)), 4280709209124899452))
            d := add(d, mul(mload(add(s, 0xc0)), 1203358955785565947))
            d := add(d, mul(mload(add(s, 0xe0)), 11202700275482992172))
            d := add(d, mul(mload(add(s, 0x100)), 13685583713509618195))
            d := add(d, mul(mload(add(s, 0x120)), 3469864161577330170))
            d := add(d, mul(mload(add(s, 0x140)), 8734130268423889220))
            d := add(d, mul(mload(add(s, 0x160)), 16917450195693745928))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 4032097614937144430), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 5682426829072761065), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 14144004233890775432), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 11476034762570105656), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 11441392943423295273), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 14245661866930276468), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 11536287954985758398), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 6483617259986966714), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 10087111781120039554), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 13728844829744097141), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 14679689325173586623), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr6(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 1054611198573910171, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 8180410513952497551))
            d := add(d, mul(mload(add(s, 0x40)), 7071292797447000945))
            d := add(d, mul(mload(add(s, 0x60)), 14180677607572215618))
            d := add(d, mul(mload(add(s, 0x80)), 6192821375005245090))
            d := add(d, mul(mload(add(s, 0xa0)), 11618722403488968531))
            d := add(d, mul(mload(add(s, 0xc0)), 16359132914868028498))
            d := add(d, mul(mload(add(s, 0xe0)), 629739239384523563))
            d := add(d, mul(mload(add(s, 0x100)), 14807849520380455651))
            d := add(d, mul(mload(add(s, 0x120)), 9453790714124186574))
            d := add(d, mul(mload(add(s, 0x140)), 13094671554168529902))
            d := add(d, mul(mload(add(s, 0x160)), 7712187332553607807))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 6304928008866363842), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 9855321538770560945), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 9435164398075715846), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 9404592978128123150), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 11002422368171462947), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 8486311906590791617), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 18361824531704888434), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 2798920999004265189), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 17909793464802401204), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 5756303597132403312), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 5858421860645672190), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr7(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 14596485233396387590, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 17023513964361815961))
            d := add(d, mul(mload(add(s, 0x40)), 4047391151444874101))
            d := add(d, mul(mload(add(s, 0x60)), 4322167285472126322))
            d := add(d, mul(mload(add(s, 0x80)), 5857702128726293638))
            d := add(d, mul(mload(add(s, 0xa0)), 5139199894843344198))
            d := add(d, mul(mload(add(s, 0xc0)), 1693515656102034708))
            d := add(d, mul(mload(add(s, 0xe0)), 12470471516364544231))
            d := add(d, mul(mload(add(s, 0x100)), 8323866952084077697))
            d := add(d, mul(mload(add(s, 0x120)), 12651873977826689095))
            d := add(d, mul(mload(add(s, 0x140)), 5067670011142229746))
            d := add(d, mul(mload(add(s, 0x160)), 396279522907796927))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 17305709116193116427), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 735829306202841815), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 14847743950994388316), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 11139080626411756670), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 7092455469264931963), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 11583767394161657005), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 15774934118411863340), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 4416857554682544229), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 9159855784268361426), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 8216101670692368083), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 16367782717227750410), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr8(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 13680159589485875108, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 16390401751368131934))
            d := add(d, mul(mload(add(s, 0x40)), 7418420403566340092))
            d := add(d, mul(mload(add(s, 0x60)), 8653653352406274042))
            d := add(d, mul(mload(add(s, 0x80)), 4118931406823846491))
            d := add(d, mul(mload(add(s, 0xa0)), 82975984786450442))
            d := add(d, mul(mload(add(s, 0xc0)), 18222397316657226499))
            d := add(d, mul(mload(add(s, 0xe0)), 2002174628128864983))
            d := add(d, mul(mload(add(s, 0x100)), 9634468324007960767))
            d := add(d, mul(mload(add(s, 0x120)), 3259584970126823840))
            d := add(d, mul(mload(add(s, 0x140)), 581370729274350312))
            d := add(d, mul(mload(add(s, 0x160)), 17755967144133734705))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 12329937970340684597), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 10602297383654186753), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 5891764497626072293), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 10671154149112267313), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 18234822653119242373), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 15287378323692558105), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 9967103142034849899), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 15861939895842675328), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 11730063476303470848), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 1586390848658847158), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 1015360682565850373), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr9(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 9441690674504273278, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 9071247654034188589))
            d := add(d, mul(mload(add(s, 0x40)), 6594541173975452315))
            d := add(d, mul(mload(add(s, 0x60)), 17782188089785283344))
            d := add(d, mul(mload(add(s, 0x80)), 3595742487221932055))
            d := add(d, mul(mload(add(s, 0xa0)), 9841642201692265487))
            d := add(d, mul(mload(add(s, 0xc0)), 1029671011456985627))
            d := add(d, mul(mload(add(s, 0xe0)), 13457875495926821529))
            d := add(d, mul(mload(add(s, 0x100)), 6870405007338730846))
            d := add(d, mul(mload(add(s, 0x120)), 12744130097658441846))
            d := add(d, mul(mload(add(s, 0x140)), 6788288399186088634))
            d := add(d, mul(mload(add(s, 0x160)), 357912856529587295))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 4417656488067463062), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 14987770745080868386), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 4702825855063868377), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 2465246157933796197), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 8034369030882576822), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 15698764330557579947), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 11839103375501390181), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 4595990697051972631), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 14148213542088135280), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 14849248616009699298), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 15807262764748562013), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr10(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 7281057872237841107, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 5607434777391338218))
            d := add(d, mul(mload(add(s, 0x40)), 15814876086124552425))
            d := add(d, mul(mload(add(s, 0x60)), 10566177234457318078))
            d := add(d, mul(mload(add(s, 0x80)), 15354864780205183334))
            d := add(d, mul(mload(add(s, 0xa0)), 15216311397122257089))
            d := add(d, mul(mload(add(s, 0xc0)), 2674093911898978557))
            d := add(d, mul(mload(add(s, 0xe0)), 16268280753066444837))
            d := add(d, mul(mload(add(s, 0x100)), 3675451000502615243))
            d := add(d, mul(mload(add(s, 0x120)), 701273502091366776))
            d := add(d, mul(mload(add(s, 0x140)), 15854278682598134666))
            d := add(d, mul(mload(add(s, 0x160)), 6924615965242507246))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 1262098398535043837), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 2436065499532941641), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 1138970283407778564), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 1825502889302643134), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 5500855066099563465), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 11666892062115297604), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 13463068267332421729), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 17516970128403465337), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 11088428730628824449), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 4615288675764694853), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 16220123440754855385), p))
            mstore(s, mod(d, p))
        }
    }
    /// Stage 1: full rounds 1-4 + partial-round init + partial rounds 0-10.
    function _run(uint256[12] memory s) private pure returns (uint256[12] memory) {
    // full round 1: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 13080132714287612933, P));
        s[1] = _sb(addmod(s[1], 8594738767457295063, P));
        s[2] = _sb(addmod(s[2], 12896916465481390516, P));
        s[3] = _sb(addmod(s[3], 1109962092811921367, P));
        s[4] = _sb(addmod(s[4], 16216730422861946898, P));
        s[5] = _sb(addmod(s[5], 10137062673499593713, P));
        s[6] = _sb(addmod(s[6], 15292064466732465823, P));
        s[7] = _sb(addmod(s[7], 17255573294985989181, P));
        s[8] = _sb(addmod(s[8], 14827154241873003558, P));
        s[9] = _sb(addmod(s[9], 2846171647972703231, P));
        s[10] = _sb(addmod(s[10], 16246264663680317601, P));
        s[11] = _sb(addmod(s[11], 14214208087951879286, P));
        // MDS mixing
        _mds(s);
        // full round 2: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 9667108687426275457, P));
        s[1] = _sb(addmod(s[1], 6470857420712283733, P));
        s[2] = _sb(addmod(s[2], 14103331940138337652, P));
        s[3] = _sb(addmod(s[3], 11854816473550292865, P));
        s[4] = _sb(addmod(s[4], 3498097497301325516, P));
        s[5] = _sb(addmod(s[5], 7947235692523864220, P));
        s[6] = _sb(addmod(s[6], 11110078701231901946, P));
        s[7] = _sb(addmod(s[7], 16384314112672821048, P));
        s[8] = _sb(addmod(s[8], 15404405912655775739, P));
        s[9] = _sb(addmod(s[9], 14077880830714445579, P));
        s[10] = _sb(addmod(s[10], 9555554662709218279, P));
        s[11] = _sb(addmod(s[11], 13859595358210603949, P));
        // MDS mixing
        _mds(s);
        // full round 3: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 16859897325061800066, P));
        s[1] = _sb(addmod(s[1], 17685474420222222349, P));
        s[2] = _sb(addmod(s[2], 17858764734618734949, P));
        s[3] = _sb(addmod(s[3], 9410011022665866671, P));
        s[4] = _sb(addmod(s[4], 12495243629579414666, P));
        s[5] = _sb(addmod(s[5], 12416945298171515742, P));
        s[6] = _sb(addmod(s[6], 5776666812364270983, P));
        s[7] = _sb(addmod(s[7], 6314421662864060481, P));
        s[8] = _sb(addmod(s[8], 7402742471423223171, P));
        s[9] = _sb(addmod(s[9], 982536713192432718, P));
        s[10] = _sb(addmod(s[10], 17321168865775127905, P));
        s[11] = _sb(addmod(s[11], 2934354895005980211, P));
        // MDS mixing
        _mds(s);
        // full round 4: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 10567510598607410195, P));
        s[1] = _sb(addmod(s[1], 8135543733717919110, P));
        s[2] = _sb(addmod(s[2], 116353493081713692, P));
        s[3] = _sb(addmod(s[3], 8029688163494945618, P));
        s[4] = _sb(addmod(s[4], 9003846637224807585, P));
        s[5] = _sb(addmod(s[5], 7052445132467233849, P));
        s[6] = _sb(addmod(s[6], 9645665432288852853, P));
        s[7] = _sb(addmod(s[7], 5446430061030868787, P));
        s[8] = _sb(addmod(s[8], 16770910634346036823, P));
        s[9] = _sb(addmod(s[9], 17708360571433944729, P));
        s[10] = _sb(addmod(s[10], 4661556288322237631, P));
        s[11] = _sb(addmod(s[11], 11977051899316327985, P));
        // MDS mixing
        _mds(s);
        assembly ("memory-safe") {
            let scr := mload(0x40)
            // mds_partial_layer_init: precompute (once per permute) the partial-round matrix.
            // lane 0 passes through; lanes 1..11 become fixed linear combinations of lanes 1..11.
            let p := 0xFFFFFFFF00000001
            mstore(s, addmod(mload(s), 4378616569090929672, p))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), 16831074976302798833, p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), 17474843094576853935, p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), 15154628183104001226, p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), 14219868664549115443, p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), 10509321604391016962, p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), 17545903601470498427, p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), 3273629310481947241, p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), 8362887214150162593, p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), 7587761356207546181, p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), 6959023468757315912, p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), 14065947794859331340, p))
            mstore(scr, mload(s))
            {
                let acc := mulmod(mload(add(s, 0x20)), 9256917872013944843, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 16687757000829461707, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 15919568759443364026, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 17628276356247382281, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 17976887162229714000, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 9191356322801962495, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 8244675934684975988, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 7268127472833019981, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 9602108300053878928, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 1540311261654516052, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 15582992301522062240, p), p)
                mstore(add(scr, 0x20), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 15893897022228540664, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 12764541860482007578, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 1487496629277845135, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 14211060579632108547, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 6791692987299703477, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 5412105005886646653, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 2125569474183208192, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 5600686741053600354, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 15610298188943525805, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 10517970165082627573, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 1540311261654516052, p), p)
                mstore(add(scr, 0x40), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 13949760578536372653, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 1073506034073544330, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 5122203447763166523, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 9180588347636943785, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 6455531853563710059, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 7077135177323540712, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 1761883289931249101, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 13703919263985638019, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 13828402413953013890, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 15610298188943525805, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 9602108300053878928, p), p)
                mstore(add(scr, 0x60), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 10441609312974976515, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 12178624353196374758, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 2200314810679404686, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 11858291964101661402, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 506729933833272474, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 13768926573657667599, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 9202082607097456696, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 155673126466762010, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 13703919263985638019, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 5600686741053600354, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 7268127472833019981, p), p)
                mstore(add(scr, 0x80), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 4189528951266599854, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 9093834777404014814, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 13521131922395904812, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 3422342838493228737, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 12479288794463684010, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 14009018616032686342, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 9665676628089346926, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 9202082607097456696, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 1761883289931249101, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 2125569474183208192, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 8244675934684975988, p), p)
                mstore(add(scr, 0xa0), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 45832257923618046, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 12470775297641857694, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 16674096007358536750, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 16717315056857949245, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 12357738834545821552, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 8447498431838444578, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 14009018616032686342, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 13768926573657667599, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 7077135177323540712, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 5412105005886646653, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 9191356322801962495, p), p)
                mstore(add(scr, 0xc0), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 8607345711887993138, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 14365012582629183475, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 12650089191056401741, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 4874593437852546498, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 14664271473160014313, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 12357738834545821552, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 12479288794463684010, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 506729933833272474, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 6455531853563710059, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 6791692987299703477, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 17976887162229714000, p), p)
                mstore(add(scr, 0xe0), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 10398036555777403988, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 17322896464470575084, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 15914053419498374975, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 14575430061120165237, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 4874593437852546498, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 16717315056857949245, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 3422342838493228737, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 11858291964101661402, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 9180588347636943785, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 14211060579632108547, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 17628276356247382281, p), p)
                mstore(add(scr, 0x100), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 13806692727776539476, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 12929063850085080619, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 14774060794419120357, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 15914053419498374975, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 12650089191056401741, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 16674096007358536750, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 13521131922395904812, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 2200314810679404686, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 5122203447763166523, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 1487496629277845135, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 15919568759443364026, p), p)
                mstore(add(scr, 0x120), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 4187764176355919243, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 8008291477586393637, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 12929063850085080619, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 17322896464470575084, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 14365012582629183475, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 12470775297641857694, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 9093834777404014814, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 12178624353196374758, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 1073506034073544330, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 12764541860482007578, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 16687757000829461707, p), p)
                mstore(add(scr, 0x140), acc)
            }
            {
                let acc := mulmod(mload(add(s, 0x20)), 4771889745340348367, p)
                acc := addmod(acc, mulmod(mload(add(s, 0x40)), 4187764176355919243, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x60)), 13806692727776539476, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x80)), 10398036555777403988, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xa0)), 8607345711887993138, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xc0)), 45832257923618046, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0xe0)), 4189528951266599854, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x100)), 10441609312974976515, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x120)), 13949760578536372653, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x140)), 15893897022228540664, p), p)
                acc := addmod(acc, mulmod(mload(add(s, 0x160)), 9256917872013944843, p), p)
                mstore(add(scr, 0x160), acc)
            }
            mstore(s, mload(scr))
            mstore(add(s, 0x20), mload(add(scr, 0x20)))
            mstore(add(s, 0x40), mload(add(scr, 0x40)))
            mstore(add(s, 0x60), mload(add(scr, 0x60)))
            mstore(add(s, 0x80), mload(add(scr, 0x80)))
            mstore(add(s, 0xa0), mload(add(scr, 0xa0)))
            mstore(add(s, 0xc0), mload(add(scr, 0xc0)))
            mstore(add(s, 0xe0), mload(add(scr, 0xe0)))
            mstore(add(s, 0x100), mload(add(scr, 0x100)))
            mstore(add(s, 0x120), mload(add(scr, 0x120)))
            mstore(add(s, 0x140), mload(add(scr, 0x140)))
            mstore(add(s, 0x160), mload(add(scr, 0x160)))
        }
        function(uint256[12] memory) internal pure[11] memory fns = [_pr0, _pr1, _pr2, _pr3, _pr4, _pr5, _pr6, _pr7, _pr8, _pr9, _pr10];
        for (uint256 i = 0; i < 11; i++) { fns[i](s); }
        return s;
    }
    /// External delegatecall entry for this stage: unpack 3 words -> 12 lanes, run the
    /// stage, repack to 3 words. The 3-scalar ABI marshals ~7x cheaper than uint256[12].
    function run(uint256 w0, uint256 w1, uint256 w2) external pure returns (uint256, uint256, uint256) {
        return _pack(_run(_unpack(w0, w1, w2)));
    }
    /// 3 words -> 12 lanes (4 lanes per word, low limb first; each lane < 2^64).
    function _unpack(uint256 w0, uint256 w1, uint256 w2) private pure returns (uint256[12] memory s) {
        assembly ("memory-safe") {
            let M := 0xFFFFFFFFFFFFFFFF
            mstore(s, and(w0, M))
            mstore(add(s, 0x20), and(shr(64, w0), M))
            mstore(add(s, 0x40), and(shr(128, w0), M))
            mstore(add(s, 0x60), shr(192, w0))
            mstore(add(s, 0x80), and(w1, M))
            mstore(add(s, 0xa0), and(shr(64, w1), M))
            mstore(add(s, 0xc0), and(shr(128, w1), M))
            mstore(add(s, 0xe0), shr(192, w1))
            mstore(add(s, 0x100), and(w2, M))
            mstore(add(s, 0x120), and(shr(64, w2), M))
            mstore(add(s, 0x140), and(shr(128, w2), M))
            mstore(add(s, 0x160), shr(192, w2))
        }
    }
    /// 12 lanes -> 3 words (inverse of _unpack).
    function _pack(uint256[12] memory s) private pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            r0 := or(or(mload(s), shl(64, mload(add(s, 0x20)))), or(shl(128, mload(add(s, 0x40))), shl(192, mload(add(s, 0x60)))))
            r1 := or(or(mload(add(s, 0x80)), shl(64, mload(add(s, 0xa0)))), or(shl(128, mload(add(s, 0xc0))), shl(192, mload(add(s, 0xe0)))))
            r2 := or(or(mload(add(s, 0x100)), shl(64, mload(add(s, 0x120)))), or(shl(128, mload(add(s, 0x140))), shl(192, mload(add(s, 0x160)))))
        }
    }
}

library PGStage2 {
    uint256 internal constant P = 0xFFFFFFFF00000001;
    /// S-box: x^7 over Goldilocks (x2=x^2, x4=x^4; x^7 = x2*x*x4). Poseidon non-linear step.
    function _sb(uint256 x) private pure returns (uint256) {
        uint256 x2 = mulmod(x, x, P);
        uint256 x4 = mulmod(x2, x2, P);
        return mulmod(mulmod(x2, x, P), x4, P);
    }
    /// MDS linear-mixing layer (Poseidon step 3). Each output lane is the circulant
    /// dot-product of the 12 input lanes with the plonky2 MDS matrix (coeffs 17,15,41,...;
    /// lane 0 also gets the +8 diagonal). Lanes are read into v0..v11 once and outputs are
    /// written in place, so no scratch/copyback is needed.
    function _mds(uint256[12] memory s) private pure {
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let v0 := mload(s)
            let v1 := mload(add(s, 0x20))
            let v2 := mload(add(s, 0x40))
            let v3 := mload(add(s, 0x60))
            let v4 := mload(add(s, 0x80))
            let v5 := mload(add(s, 0xa0))
            let v6 := mload(add(s, 0xc0))
            let v7 := mload(add(s, 0xe0))
            let v8 := mload(add(s, 0x100))
            let v9 := mload(add(s, 0x120))
            let v10 := mload(add(s, 0x140))
            let v11 := mload(add(s, 0x160))
            // --- compute all 12 mixed lanes from v0..v11, write in place ---
            mstore(s, mod(add(add(add(add(add(add(add(add(add(add(add(add(mul(v0, 17), mul(v1, 15)), mul(v2, 41)), mul(v3, 16)), mul(v4, 2)), mul(v5, 28)), mul(v6, 13)), mul(v7, 13)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(v0, 8)), p))
            mstore(add(s, 0x20), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v1, 17), mul(v2, 15)), mul(v3, 41)), mul(v4, 16)), mul(v5, 2)), mul(v6, 28)), mul(v7, 13)), mul(v8, 13)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(v0, 20)), p))
            mstore(add(s, 0x40), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v2, 17), mul(v3, 15)), mul(v4, 41)), mul(v5, 16)), mul(v6, 2)), mul(v7, 28)), mul(v8, 13)), mul(v9, 13)), mul(v10, 39)), mul(v11, 18)), mul(v0, 34)), mul(v1, 20)), p))
            mstore(add(s, 0x60), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v3, 17), mul(v4, 15)), mul(v5, 41)), mul(v6, 16)), mul(v7, 2)), mul(v8, 28)), mul(v9, 13)), mul(v10, 13)), mul(v11, 39)), mul(v0, 18)), mul(v1, 34)), mul(v2, 20)), p))
            mstore(add(s, 0x80), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v4, 17), mul(v5, 15)), mul(v6, 41)), mul(v7, 16)), mul(v8, 2)), mul(v9, 28)), mul(v10, 13)), mul(v11, 13)), mul(v0, 39)), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), p))
            mstore(add(s, 0xa0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v5, 17), mul(v6, 15)), mul(v7, 41)), mul(v8, 16)), mul(v9, 2)), mul(v10, 28)), mul(v11, 13)), mul(v0, 13)), mul(v1, 39)), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), p))
            mstore(add(s, 0xc0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v6, 17), mul(v7, 15)), mul(v8, 41)), mul(v9, 16)), mul(v10, 2)), mul(v11, 28)), mul(v0, 13)), mul(v1, 13)), mul(v2, 39)), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), p))
            mstore(add(s, 0xe0), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v7, 17), mul(v8, 15)), mul(v9, 41)), mul(v10, 16)), mul(v11, 2)), mul(v0, 28)), mul(v1, 13)), mul(v2, 13)), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), p))
            mstore(add(s, 0x100), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v8, 17), mul(v9, 15)), mul(v10, 41)), mul(v11, 16)), mul(v0, 2)), mul(v1, 28)), mul(v2, 13)), mul(v3, 13)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), p))
            mstore(add(s, 0x120), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v9, 17), mul(v10, 15)), mul(v11, 41)), mul(v0, 16)), mul(v1, 2)), mul(v2, 28)), mul(v3, 13)), mul(v4, 13)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), p))
            mstore(add(s, 0x140), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v10, 17), mul(v11, 15)), mul(v0, 41)), mul(v1, 16)), mul(v2, 2)), mul(v3, 28)), mul(v4, 13)), mul(v5, 13)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), p))
            mstore(add(s, 0x160), mod(add(add(add(add(add(add(add(add(add(add(add(mul(v11, 17), mul(v0, 15)), mul(v1, 41)), mul(v2, 16)), mul(v3, 2)), mul(v4, 28)), mul(v5, 13)), mul(v6, 13)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr11(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 8581622869689923244, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 1637471090675303584))
            d := add(d, mul(mload(add(s, 0x40)), 4375318637115686030))
            d := add(d, mul(mload(add(s, 0x60)), 12136810621975340177))
            d := add(d, mul(mload(add(s, 0x80)), 105995675382122926))
            d := add(d, mul(mload(add(s, 0xa0)), 5987457663538146171))
            d := add(d, mul(mload(add(s, 0xc0)), 15717760330284389791))
            d := add(d, mul(mload(add(s, 0xe0)), 14670439359715404205))
            d := add(d, mul(mload(add(s, 0x100)), 5464349733274908045))
            d := add(d, mul(mload(add(s, 0x120)), 8636933789572244554))
            d := add(d, mul(mload(add(s, 0x140)), 9769580318971544573))
            d := add(d, mul(mload(add(s, 0x160)), 9102363839782539970))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 9570691013274316785), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 15613851939195720118), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 3699802456427549428), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 14363933592354809237), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 13863573127618181752), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 11428524752427198786), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 1512236798846210343), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 15492557605200192531), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 4471766256042329601), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 12055723375080267479), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 16720313860519281958), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr12(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 12649521141086658944, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 13571765139831017037))
            d := add(d, mul(mload(add(s, 0x40)), 818883284762741475))
            d := add(d, mul(mload(add(s, 0x60)), 11800681286871024320))
            d := add(d, mul(mload(add(s, 0x80)), 4228007315495729552))
            d := add(d, mul(mload(add(s, 0xa0)), 9681067057645014410))
            d := add(d, mul(mload(add(s, 0xc0)), 10160317193366865607))
            d := add(d, mul(mload(add(s, 0xe0)), 7974952474492003064))
            d := add(d, mul(mload(add(s, 0x100)), 311630947502800583))
            d := add(d, mul(mload(add(s, 0x120)), 16977972518193735910))
            d := add(d, mul(mload(add(s, 0x140)), 615971843838204966))
            d := add(d, mul(mload(add(s, 0x160)), 17678304266887460895))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 2561042796132833389), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 10464014529858294964), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 14401165907148431066), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 2413453332765052361), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 14620959153325857181), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 16368665425253279930), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 8913590094823920770), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 4357291993877750483), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 18315259589408480902), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 7040130461852977952), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 16913088801316332783), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr13(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 13316298133620363637, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 12163901532241384359))
            d := add(d, mul(mload(add(s, 0x40)), 5826724299253731684))
            d := add(d, mul(mload(add(s, 0x60)), 17423022063725297026))
            d := add(d, mul(mload(add(s, 0x80)), 18082834829462388363))
            d := add(d, mul(mload(add(s, 0xa0)), 10626880031407069622))
            d := add(d, mul(mload(add(s, 0xc0)), 1952478840402025861))
            d := add(d, mul(mload(add(s, 0xe0)), 9036125440908740987))
            d := add(d, mul(mload(add(s, 0x100)), 1042941967034175129))
            d := add(d, mul(mload(add(s, 0x120)), 13710136024884221835))
            d := add(d, mul(mload(add(s, 0x140)), 3995229588248274477))
            d := add(d, mul(mload(add(s, 0x160)), 11993482789377134210))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 15483762529902925134), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 17034733783218795199), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 18136305076967260316), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 15896912869485945382), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 475392759889361288), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 1823867867187688822), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 8817375076608676110), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 8857453095514132937), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 17995601973761478278), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 18042919419769033432), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 17356815683605755783), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr14(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 10757436128916982213, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 12697151891341221277))
            d := add(d, mul(mload(add(s, 0x40)), 13408757364964309332))
            d := add(d, mul(mload(add(s, 0x60)), 14636730641620356003))
            d := add(d, mul(mload(add(s, 0x80)), 2917199062768996165))
            d := add(d, mul(mload(add(s, 0xa0)), 11768157571822112934))
            d := add(d, mul(mload(add(s, 0xc0)), 15407074889369976729))
            d := add(d, mul(mload(add(s, 0xe0)), 3320959039775894817))
            d := add(d, mul(mload(add(s, 0x100)), 16277817307991958146))
            d := add(d, mul(mload(add(s, 0x120)), 7362033657200491320))
            d := add(d, mul(mload(add(s, 0x140)), 9990801137147894185))
            d := add(d, mul(mload(add(s, 0x160)), 14676096006818979429))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 853567178463642200), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 781481719657018312), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 864881582238738022), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 776585443674182031), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 868289454518583667), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 873991676947315745), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 825112067366636056), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 904067466148006484), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 864277137123579536), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 785755357347442049), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 861609966041484849), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr15(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 16047932205709436219, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 17204396082766500862))
            d := add(d, mul(mload(add(s, 0x40)), 14458712079049372979))
            d := add(d, mul(mload(add(s, 0x60)), 17287567422807715153))
            d := add(d, mul(mload(add(s, 0x80)), 13337198174858709409))
            d := add(d, mul(mload(add(s, 0xa0)), 7624105753184612060))
            d := add(d, mul(mload(add(s, 0xc0)), 17074874386857691157))
            d := add(d, mul(mload(add(s, 0xe0)), 2909991590741947335))
            d := add(d, mul(mload(add(s, 0x100)), 14770785872198722410))
            d := add(d, mul(mload(add(s, 0x120)), 17719065353010659993))
            d := add(d, mul(mload(add(s, 0x140)), 14898159957685527729))
            d := add(d, mul(mload(add(s, 0x160)), 12135206555549668255))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 3644417860664408), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 3335591043919560), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 3691922388548390), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 3315658209334511), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 3706319247139923), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 3730913850857153), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 3522914930316824), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 3859199185371348), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 3689373458353040), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 3354664939836449), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 3677753419960785), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr16(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 17301616663694082334, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 15626888021543284549))
            d := add(d, mul(mload(add(s, 0x40)), 12464927884746769804))
            d := add(d, mul(mload(add(s, 0x60)), 1471467344747928256))
            d := add(d, mul(mload(add(s, 0x80)), 11413582290460358915))
            d := add(d, mul(mload(add(s, 0xa0)), 9282109700482247280))
            d := add(d, mul(mload(add(s, 0xc0)), 17976144115670124039))
            d := add(d, mul(mload(add(s, 0xe0)), 16456828278798000758))
            d := add(d, mul(mload(add(s, 0x100)), 1008181782916845414))
            d := add(d, mul(mload(add(s, 0x120)), 17610348098917415827))
            d := add(d, mul(mload(add(s, 0x140)), 204173067177706516))
            d := add(d, mul(mload(add(s, 0x160)), 15964669298669259045))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 15551163980504), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 14240130616264), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 15771333781862), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 14149230256207), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 15820017123763), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 15936503968609), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 15031975505304), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 16471548413268), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 15760188783376), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 14317015483073), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 15696239618801), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr17(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 11667617191967502297, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 13932676290161493411))
            d := add(d, mul(mload(add(s, 0x40)), 14699132604785301972))
            d := add(d, mul(mload(add(s, 0x60)), 3744215611852980773))
            d := add(d, mul(mload(add(s, 0x80)), 2709414263278899107))
            d := add(d, mul(mload(add(s, 0xa0)), 806263865491310800))
            d := add(d, mul(mload(add(s, 0xc0)), 7317365142041602481))
            d := add(d, mul(mload(add(s, 0xe0)), 16776386564962992796))
            d := add(d, mul(mload(add(s, 0x100)), 11652640766067723448))
            d := add(d, mul(mload(add(s, 0x120)), 1016370456237928832))
            d := add(d, mul(mload(add(s, 0x140)), 961864172302955643))
            d := add(d, mul(mload(add(s, 0x160)), 11539305592151691719))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 66326084760), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 60935297352), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 67215299046), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 60348857903), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 67671686739), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 67914356993), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 64112320984), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 70469953364), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 67111186256), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 61118430945), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 67182327505), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr18(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 9658934864843380542, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 5260886902259565990))
            d := add(d, mul(mload(add(s, 0x40)), 16171862215293778203))
            d := add(d, mul(mload(add(s, 0x60)), 771114262717812991))
            d := add(d, mul(mload(add(s, 0x80)), 10575516421403467499))
            d := add(d, mul(mload(add(s, 0xa0)), 13137658605724015568))
            d := add(d, mul(mload(add(s, 0xc0)), 4324696043571725046))
            d := add(d, mul(mload(add(s, 0xe0)), 17177140657993423090))
            d := add(d, mul(mload(add(s, 0x100)), 11675287481120654357))
            d := add(d, mul(mload(add(s, 0x120)), 215782959819461329))
            d := add(d, mul(mload(add(s, 0x140)), 16817340479494209298))
            d := add(d, mul(mload(add(s, 0x160)), 2305466969888960689))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 286463800), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 257349000), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 285544326), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 260345679), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 286599123), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 289630625), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 275722040), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 300075668), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 285878768), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 262796737), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 284566993), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr19(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 3498090033303964622, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 9354449820649144563))
            d := add(d, mul(mload(add(s, 0x40)), 17638200638691477463))
            d := add(d, mul(mload(add(s, 0x60)), 17096907883840532417))
            d := add(d, mul(mload(add(s, 0x80)), 795566415402858691))
            d := add(d, mul(mload(add(s, 0xa0)), 12763188014703795610))
            d := add(d, mul(mload(add(s, 0xc0)), 2111548358776179736))
            d := add(d, mul(mload(add(s, 0xe0)), 7338420082729848069))
            d := add(d, mul(mload(add(s, 0x100)), 11736253547470159946))
            d := add(d, mul(mload(add(s, 0x120)), 11882449274483722406))
            d := add(d, mul(mload(add(s, 0x140)), 13880779032198735515))
            d := add(d, mul(mload(add(s, 0x160)), 12012886003476663648))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 1177368), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 1095368), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 1264278), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 1101695), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 1199363), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 1308833), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 1145944), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 1256596), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 1265600), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 1089681), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 1214817), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr20(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 1930488375833774198, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 9561079619973624339))
            d := add(d, mul(mload(add(s, 0x40)), 3427032003991111411))
            d := add(d, mul(mload(add(s, 0x60)), 16026109245305520857))
            d := add(d, mul(mload(add(s, 0x80)), 842178779993054962))
            d := add(d, mul(mload(add(s, 0xa0)), 6620069080479782436))
            d := add(d, mul(mload(add(s, 0xc0)), 520632651104976912))
            d := add(d, mul(mload(add(s, 0xe0)), 5977708219320356796))
            d := add(d, mul(mload(add(s, 0x100)), 14677035874152442976))
            d := add(d, mul(mload(add(s, 0x120)), 12438555763140714832))
            d := add(d, mul(mload(add(s, 0x140)), 10308634069667372976))
            d := add(d, mul(mload(add(s, 0x160)), 1889137300031443018))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 4864), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 5968), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 4430), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 4895), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 5755), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 4977), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 4656), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 6188), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 4968), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 3889), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 5577), p))
            mstore(s, mod(d, p))
        }
    }
    /// Partial round (constants for this round only; see _pr0 for the structure).
    function _pr21(uint256[12] memory s) private pure {
        // S-box(s0)を scratch メモリに退避して再利用 → via_ir の s0 再計算(rematerialize)を防ぐ。
        // 関数ポインタは使わない(他関数の via_ir スタック割当を乱さないため)。
        assembly ("memory-safe") {
            let p := 0xFFFFFFFF00000001
            let scr := mload(0x40)
            let v0 := mload(s)
            let x2 := mulmod(v0, v0, p)
            let x4 := mulmod(x2, x2, p)
            mstore(scr, addmod(mulmod(mulmod(x2, v0, p), x4, p), 0, p))
            let d := mul(mload(scr), 25)
            d := add(d, mul(mload(add(s, 0x20)), 4233023069765094533))
            d := add(d, mul(mload(add(s, 0x40)), 11320301090717319475))
            d := add(d, mul(mload(add(s, 0x60)), 529847152638273925))
            d := add(d, mul(mload(add(s, 0x80)), 11362416581384070759))
            d := add(d, mul(mload(add(s, 0xa0)), 3913471784331119128))
            d := add(d, mul(mload(add(s, 0xc0)), 5817936720856651185))
            d := add(d, mul(mload(add(s, 0xe0)), 17448019282603275260))
            d := add(d, mul(mload(add(s, 0x100)), 3425091249974323865))
            d := add(d, mul(mload(add(s, 0x120)), 13157846471433414730))
            d := add(d, mul(mload(add(s, 0x140)), 673370378535461536))
            d := add(d, mul(mload(add(s, 0x160)), 846766219905577371))
            mstore(add(s, 0x20), addmod(mload(add(s, 0x20)), mul(mload(scr), 20), p))
            mstore(add(s, 0x40), addmod(mload(add(s, 0x40)), mul(mload(scr), 34), p))
            mstore(add(s, 0x60), addmod(mload(add(s, 0x60)), mul(mload(scr), 18), p))
            mstore(add(s, 0x80), addmod(mload(add(s, 0x80)), mul(mload(scr), 39), p))
            mstore(add(s, 0xa0), addmod(mload(add(s, 0xa0)), mul(mload(scr), 13), p))
            mstore(add(s, 0xc0), addmod(mload(add(s, 0xc0)), mul(mload(scr), 13), p))
            mstore(add(s, 0xe0), addmod(mload(add(s, 0xe0)), mul(mload(scr), 28), p))
            mstore(add(s, 0x100), addmod(mload(add(s, 0x100)), mul(mload(scr), 2), p))
            mstore(add(s, 0x120), addmod(mload(add(s, 0x120)), mul(mload(scr), 16), p))
            mstore(add(s, 0x140), addmod(mload(add(s, 0x140)), mul(mload(scr), 41), p))
            mstore(add(s, 0x160), addmod(mload(add(s, 0x160)), mul(mload(scr), 15), p))
            mstore(s, mod(d, p))
        }
    }
    /// Stage 2: partial rounds 11-21 + full rounds 5-8.
    function _run(uint256[12] memory s) private pure returns (uint256[12] memory) {
        function(uint256[12] memory) internal pure[11] memory fns = [_pr11, _pr12, _pr13, _pr14, _pr15, _pr16, _pr17, _pr18, _pr19, _pr20, _pr21];
        for (uint256 i = 0; i < 11; i++) { fns[i](s); }
    // full round 5: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 5142217010456550622, P));
        s[1] = _sb(addmod(s[1], 1775580461722730120, P));
        s[2] = _sb(addmod(s[2], 161694268822794344, P));
        s[3] = _sb(addmod(s[3], 1518963253808031703, P));
        s[4] = _sb(addmod(s[4], 16475258091652710137, P));
        s[5] = _sb(addmod(s[5], 119575899007375159, P));
        s[6] = _sb(addmod(s[6], 1275863735937973999, P));
        s[7] = _sb(addmod(s[7], 16539412514520642374, P));
        s[8] = _sb(addmod(s[8], 2303365191438051950, P));
        s[9] = _sb(addmod(s[9], 6435126839960916075, P));
        s[10] = _sb(addmod(s[10], 17794599201026020053, P));
        s[11] = _sb(addmod(s[11], 13847097589277840330, P));
        // MDS mixing
        _mds(s);
        // full round 6: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 16645869274577729720, P));
        s[1] = _sb(addmod(s[1], 8039205965509554440, P));
        s[2] = _sb(addmod(s[2], 4788586935019371140, P));
        s[3] = _sb(addmod(s[3], 15129007200040077746, P));
        s[4] = _sb(addmod(s[4], 2055561615223771341, P));
        s[5] = _sb(addmod(s[5], 4149731103701412892, P));
        s[6] = _sb(addmod(s[6], 10268130195734144189, P));
        s[7] = _sb(addmod(s[7], 13406631635880074708, P));
        s[8] = _sb(addmod(s[8], 11429218277824986203, P));
        s[9] = _sb(addmod(s[9], 15773968030812198565, P));
        s[10] = _sb(addmod(s[10], 16050275277550506872, P));
        s[11] = _sb(addmod(s[11], 11858586752031736643, P));
        // MDS mixing
        _mds(s);
        // full round 7: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 8927746344866569756, P));
        s[1] = _sb(addmod(s[1], 11802068403177695792, P));
        s[2] = _sb(addmod(s[2], 157833420806751556, P));
        s[3] = _sb(addmod(s[3], 4698875910749767878, P));
        s[4] = _sb(addmod(s[4], 1616722774788291698, P));
        s[5] = _sb(addmod(s[5], 3990951895163748090, P));
        s[6] = _sb(addmod(s[6], 16758609224720795472, P));
        s[7] = _sb(addmod(s[7], 3045571693290741477, P));
        s[8] = _sb(addmod(s[8], 9281634245289836419, P));
        s[9] = _sb(addmod(s[9], 13517688176723875370, P));
        s[10] = _sb(addmod(s[10], 7961395585333219380, P));
        s[11] = _sb(addmod(s[11], 1606574359105691080, P));
        // MDS mixing
        _mds(s);
        // full round 8: add round constant + S-box(x^7) on every lane
        s[0] = _sb(addmod(s[0], 17564372683613562171, P));
        s[1] = _sb(addmod(s[1], 4664015225343144418, P));
        s[2] = _sb(addmod(s[2], 6133721340680280128, P));
        s[3] = _sb(addmod(s[3], 2667022304383014929, P));
        s[4] = _sb(addmod(s[4], 12316557761857340230, P));
        s[5] = _sb(addmod(s[5], 10375614850625292317, P));
        s[6] = _sb(addmod(s[6], 8141542666379135068, P));
        s[7] = _sb(addmod(s[7], 9185476451083834432, P));
        s[8] = _sb(addmod(s[8], 4991072365274649547, P));
        s[9] = _sb(addmod(s[9], 17398204971778820365, P));
        s[10] = _sb(addmod(s[10], 16127888338958422584, P));
        s[11] = _sb(addmod(s[11], 13586792051317758204, P));
        // MDS mixing
        _mds(s);
        return s;
    }
    /// External delegatecall entry for this stage: unpack 3 words -> 12 lanes, run the
    /// stage, repack to 3 words. The 3-scalar ABI marshals ~7x cheaper than uint256[12].
    function run(uint256 w0, uint256 w1, uint256 w2) external pure returns (uint256, uint256, uint256) {
        return _pack(_run(_unpack(w0, w1, w2)));
    }
    /// 3 words -> 12 lanes (4 lanes per word, low limb first; each lane < 2^64).
    function _unpack(uint256 w0, uint256 w1, uint256 w2) private pure returns (uint256[12] memory s) {
        assembly ("memory-safe") {
            let M := 0xFFFFFFFFFFFFFFFF
            mstore(s, and(w0, M))
            mstore(add(s, 0x20), and(shr(64, w0), M))
            mstore(add(s, 0x40), and(shr(128, w0), M))
            mstore(add(s, 0x60), shr(192, w0))
            mstore(add(s, 0x80), and(w1, M))
            mstore(add(s, 0xa0), and(shr(64, w1), M))
            mstore(add(s, 0xc0), and(shr(128, w1), M))
            mstore(add(s, 0xe0), shr(192, w1))
            mstore(add(s, 0x100), and(w2, M))
            mstore(add(s, 0x120), and(shr(64, w2), M))
            mstore(add(s, 0x140), and(shr(128, w2), M))
            mstore(add(s, 0x160), shr(192, w2))
        }
    }
    /// 12 lanes -> 3 words (inverse of _unpack).
    function _pack(uint256[12] memory s) private pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            r0 := or(or(mload(s), shl(64, mload(add(s, 0x20)))), or(shl(128, mload(add(s, 0x40))), shl(192, mload(add(s, 0x60)))))
            r1 := or(or(mload(add(s, 0x80)), shl(64, mload(add(s, 0xa0)))), or(shl(128, mload(add(s, 0xc0))), shl(192, mload(add(s, 0xe0)))))
            r2 := or(or(mload(add(s, 0x100)), shl(64, mload(add(s, 0x120)))), or(shl(128, mload(add(s, 0x140))), shl(192, mload(add(s, 0x160)))))
        }
    }
}

library PoseidonGoldilocks {
    /// Poseidon-Goldilocks permutation. Pack the 12 lanes into 3 words, pipeline the 4
    /// stages (A: full1-4+init, B/C: partial, D: full5-8) by delegatecall, then unpack.
    function permute(uint256[12] memory s) internal pure returns (uint256[12] memory) {
        uint256 w0;
        uint256 w1;
        uint256 w2;
        // pack 12 limbs (each < 2^64) into 3 words once, then pipeline the 4 stages as 3 scalars
        // (delegatecall marshaling of uint256[12] ~4.9k each -> 3 scalars ~0.6k each).
        assembly ("memory-safe") {
            w0 := or(or(mload(s), shl(64, mload(add(s, 0x20)))), or(shl(128, mload(add(s, 0x40))), shl(192, mload(add(s, 0x60)))))
            w1 := or(or(mload(add(s, 0x80)), shl(64, mload(add(s, 0xa0)))), or(shl(128, mload(add(s, 0xc0))), shl(192, mload(add(s, 0xe0)))))
            w2 := or(or(mload(add(s, 0x100)), shl(64, mload(add(s, 0x120)))), or(shl(128, mload(add(s, 0x140))), shl(192, mload(add(s, 0x160)))))
        }
        (w0, w1, w2) = PGStage1.run(w0, w1, w2);
        (w0, w1, w2) = PGStage2.run(w0, w1, w2);
        assembly ("memory-safe") {
            let M := 0xFFFFFFFFFFFFFFFF
            mstore(s, and(w0, M))
            mstore(add(s, 0x20), and(shr(64, w0), M))
            mstore(add(s, 0x40), and(shr(128, w0), M))
            mstore(add(s, 0x60), shr(192, w0))
            mstore(add(s, 0x80), and(w1, M))
            mstore(add(s, 0xa0), and(shr(64, w1), M))
            mstore(add(s, 0xc0), and(shr(128, w1), M))
            mstore(add(s, 0xe0), shr(192, w1))
            mstore(add(s, 0x100), and(w2, M))
            mstore(add(s, 0x120), and(shr(64, w2), M))
            mstore(add(s, 0x140), and(shr(128, w2), M))
            mstore(add(s, 0x160), shr(192, w2))
        }
        return s;
    }

    /// Goldilocks prime p = 2^64 - 2^32 + 1.
    uint256 internal constant P = 0xFFFFFFFF00000001;

    /// @notice POD2 / plonky2 fixed-width hash. Initializes the 12-lane state to `flag` in every lane,
    ///         overwrites the first 8 lanes with the (canonicalized) `inputs`, applies one permutation,
    ///         and returns the first 4 output lanes. This mirrors
    ///         reference/poseidon_reference.py:hash_with_flag — flag=1 for KV (leaf) hashes, flag=2 for
    ///         node hashes in the POD2 SMT.
    /// @param flag    The capacity/domain flag used to fill the state before the inputs are written.
    /// @param inputs  The 8 field-element inputs (reduced mod p so each lane is a canonical Goldilocks elem).
    /// @return out    The first 4 lanes of the permuted state (the hash digest).
    function hashWithFlag(uint256 flag, uint256[8] memory inputs) internal pure returns (uint256[4] memory out) {
        uint256[12] memory s;
        uint256 f = flag % P;
        for (uint256 i = 0; i < 12; i++) {
            s[i] = f;
        }
        for (uint256 i = 0; i < 8; i++) {
            s[i] = inputs[i] % P;
        }
        s = permute(s);
        out[0] = s[0];
        out[1] = s[1];
        out[2] = s[2];
        out[3] = s[3];
    }
}
