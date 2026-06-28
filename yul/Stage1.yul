// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
object "Stage1" {
  code { datacopy(0, dataoffset("runtime"), datasize("runtime")) return(0, datasize("runtime")) }
  object "runtime" {
    code {
      // Hand-written, bit-exact Yul re-implementation of library PGStage1 (src/PoseidonGoldilocks.sol).
      // Mirrors yul/Stage2.yul: NO function-selector dispatch — this object is delegatecall'd from a
      // single site (PoseidonGoldilocks.permute -> PGStage1.run) with a fixed calldata layout. The caller
      // still ABI-encodes run(uint256,uint256,uint256), so the three state words sit at calldata 4/36/68;
      // we read them directly without verifying the selector.
      //
      // Stage1 pipeline (differs from Stage2):
      //   unpack(calldata) -> full rounds 1..4 -> mds_partial_layer_init -> partial rounds 0..10 -> pack
      // After partial round 10 every lane is already reduced (< 2^64), so the tail just packs the 12
      // lanes into 3 return words (4 lanes/word, low limb first) and returns — there is no final MDS.
      //
      // Reuses Stage2's proven idioms verbatim:
      //   - Full-round block: add round constant, inline x^7 S-box, then the reassociated circulant MDS
      //     (coefficients IDENTICAL to Stage2; copied exactly). Written to memory lanes 0x00..0x160.
      //     MDS outputs are left UNREDUCED (< ~2^75); the next round's S-box and the init layer's
      //     addmod/mulmod reduce mod p, so the result is bit-exact with solc (which reduces eagerly).
      //   - Partial-round block: same shape as Stage1's solc _pr — s0 = S-box(lane0)+RC (reduced),
      //     new lane0 = 25*s0 + dot(lanes1..11, w_hat), lane_j += s0*v_j (reduced via addmod each round
      //     so the direct pack at the end sees canonical < 2^64 lanes). Only constants differ per round.

      // The main body is wrapped in a block so its locals (p, v0..v11) are siblings to — and thus do
      // not collide with — the identically named locals inside fr() (Yul forbids name shadowing).
      {
      let p := 0xFFFFFFFF00000001

      // --- full rounds 1..4: addRC + x^7 S-box on all 12 lanes, then full circulant MDS ---
      { // full round 1 (inlined from fr; reuses outer p)
        // FUSED unpack x round-1 S-box inputs: extract each 64-bit lane straight from the 3 calldata
        // state words (calldata 4/36/68, 4 lanes/word, low limb first) into the round-1 S-box input,
        // instead of writing 12 lanes to memory and re-reading them. Drops 12 unpack mstore + 12 round-1
        // mload (24 memory ops). Bit-exact: same extracted lane values, same RC, same S-box. The three
        // words are loaded just-in-time (w -> lanes 0..3, then reused for 4..7, then 8..11) so each word
        // dies before the next loads, keeping stack depth bounded. Memory 0x00..0x160 is populated by
        // this round's MDS mstores below, so rounds 2..4 still read it. Extraction is identical to the
        // old unpack: lanes 0..2/4..6/8..10 = and(shr(k,w),M) (M=2^64-1), lanes 3/7/11 = shr(192,w).
        let M := 0xFFFFFFFFFFFFFFFF
        let w := calldataload(4)
        let v0 := add(and(w, M), 13080132714287612933)
        { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
        let v1 := add(and(shr(64, w), M), 8594738767457295063)
        { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
        let v2 := add(and(shr(128, w), M), 12896916465481390516)
        { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
        let v3 := add(shr(192, w), 1109962092811921367)
        { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
        w := calldataload(36)
        let v4 := add(and(w, M), 16216730422861946898)
        { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
        let v5 := add(and(shr(64, w), M), 10137062673499593713)
        { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
        let v6 := add(and(shr(128, w), M), 15292064466732465823)
        { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
        let v7 := add(shr(192, w), 17255573294985989181)
        { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
        w := calldataload(68)
        let v8 := add(and(w, M), 14827154241873003558)
        { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
        let v9 := add(and(shr(64, w), M), 2846171647972703231)
        { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
        let v10 := add(and(shr(128, w), M), 16246264663680317601)
        { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
        let v11 := add(shr(192, w), 14214208087951879286)
        { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
        mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
        mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
        mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
        mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
        mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
        mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
        mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
        mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
        mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
        mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
        mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
        mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      { // full round 2 (inlined from fr; reuses outer p)
        let v0 := add(mload(0x00), 9667108687426275457)
        { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
        let v1 := add(mload(0x20), 6470857420712283733)
        { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
        let v2 := add(mload(0x40), 14103331940138337652)
        { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
        let v3 := add(mload(0x60), 11854816473550292865)
        { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
        let v4 := add(mload(0x80), 3498097497301325516)
        { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
        let v5 := add(mload(0xa0), 7947235692523864220)
        { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
        let v6 := add(mload(0xc0), 11110078701231901946)
        { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
        let v7 := add(mload(0xe0), 16384314112672821048)
        { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
        let v8 := add(mload(0x100), 15404405912655775739)
        { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
        let v9 := add(mload(0x120), 14077880830714445579)
        { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
        let v10 := add(mload(0x140), 9555554662709218279)
        { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
        let v11 := add(mload(0x160), 13859595358210603949)
        { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
        mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
        mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
        mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
        mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
        mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
        mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
        mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
        mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
        mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
        mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
        mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
        mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      { // full round 3 (inlined from fr; reuses outer p)
        let v0 := add(mload(0x00), 16859897325061800066)
        { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
        let v1 := add(mload(0x20), 17685474420222222349)
        { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
        let v2 := add(mload(0x40), 17858764734618734949)
        { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
        let v3 := add(mload(0x60), 9410011022665866671)
        { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
        let v4 := add(mload(0x80), 12495243629579414666)
        { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
        let v5 := add(mload(0xa0), 12416945298171515742)
        { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
        let v6 := add(mload(0xc0), 5776666812364270983)
        { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
        let v7 := add(mload(0xe0), 6314421662864060481)
        { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
        let v8 := add(mload(0x100), 7402742471423223171)
        { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
        let v9 := add(mload(0x120), 982536713192432718)
        { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
        let v10 := add(mload(0x140), 17321168865775127905)
        { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
        let v11 := add(mload(0x160), 2934354895005980211)
        { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
        mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
        mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
        mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
        mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
        mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
        mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
        mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
        mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
        mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
        mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
        mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
        mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      // --- full round 4 FUSED with mds_partial_layer_init: round-4's 12 MDS output lanes are kept on
      //     the STACK (a0..a11 = round-4 S-box outputs; the MDS dot products are computed inline into the
      //     init layer's post-RC adds) instead of being written to memory 0x00..0x160 and re-read. This
      //     drops the 12 round-4 mstore + the init layer's 12 mload (24 memory ops) entirely.
      //     mds_partial_layer_init then adds a 12-element RC vector, lane0 passes through while lanes
      //     1..11 become fixed linear combinations. Faithful translation of solc PGStage1._run. ---
      let v0 let v7 let v8 let v9 let v10 let v11
      {
        // S-box of full round 4 (add RC, x^7), outputs a0..a11 (reduced < p < 2^64), kept on stack.
        let a0 := add(mload(0x00), 10567510598607410195)
        { let x2 := mul(a0,a0) a0 := mulmod(mul(x2,a0), mulmod(x2,x2,p), p) }
        let a1 := add(mload(0x20), 8135543733717919110)
        { let x2 := mul(a1,a1) a1 := mulmod(mul(x2,a1), mulmod(x2,x2,p), p) }
        let a2 := add(mload(0x40), 116353493081713692)
        { let x2 := mul(a2,a2) a2 := mulmod(mul(x2,a2), mulmod(x2,x2,p), p) }
        let a3 := add(mload(0x60), 8029688163494945618)
        { let x2 := mul(a3,a3) a3 := mulmod(mul(x2,a3), mulmod(x2,x2,p), p) }
        let a4 := add(mload(0x80), 9003846637224807585)
        { let x2 := mul(a4,a4) a4 := mulmod(mul(x2,a4), mulmod(x2,x2,p), p) }
        let a5 := add(mload(0xa0), 7052445132467233849)
        { let x2 := mul(a5,a5) a5 := mulmod(mul(x2,a5), mulmod(x2,x2,p), p) }
        let a6 := add(mload(0xc0), 9645665432288852853)
        { let x2 := mul(a6,a6) a6 := mulmod(mul(x2,a6), mulmod(x2,x2,p), p) }
        let a7 := add(mload(0xe0), 5446430061030868787)
        { let x2 := mul(a7,a7) a7 := mulmod(mul(x2,a7), mulmod(x2,x2,p), p) }
        let a8 := add(mload(0x100), 16770910634346036823)
        { let x2 := mul(a8,a8) a8 := mulmod(mul(x2,a8), mulmod(x2,x2,p), p) }
        let a9 := add(mload(0x120), 17708360571433944729)
        { let x2 := mul(a9,a9) a9 := mulmod(mul(x2,a9), mulmod(x2,x2,p), p) }
        let a10 := add(mload(0x140), 4661556288322237631)
        { let x2 := mul(a10,a10) a10 := mulmod(mul(x2,a10), mulmod(x2,x2,p), p) }
        let a11 := add(mload(0x160), 11977051899316327985)
        { let x2 := mul(a11,a11) a11 := mulmod(mul(x2,a11), mulmod(x2,x2,p), p) }

        // FUSED full-round-4 MDS x mds_partial_layer_init (COMPOSED): each init output lane is a
        // fixed integer-linear form in the round-4 S-box outputs a0..a11, obtained by substituting
        // round-4's MDS (m_k = dot(a, mdscoef_k)) into the init dot products and folding constants:
        //   out_j = sum_l a_l * C[j][l] + const_j,  C[j][l] = sum_k initcoef[j][k]*mdscoef[k][l],
        //   const_j = sum_k initcoef[j][k]*initRC_k.  This is integer-equal to the old two-step
        //   (round-4 MDS -> 12 mstore -> 12 mload -> +initRC -> init dot) by distributivity over Z, so
        //   bit-exact, and it drops all 24 handoff memory ops. lane0 passes through: v0 = m_0 + initRC_0.
        //   Bound: C[j][l] < 2^72, a_l < 2^64 -> term < 2^136; 12-term sum < 2^140; +const_j(<2^131)
        //   < 2^141 << 2^256 (no truncation). v0 = dot(a, mdscoef_0)(<2^73) + initRC_0(<2^64) < 2^73.
        v0 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 25), mul(a1, 15)), mul(a2, 41)), mul(a3, 16)), mul(a4, 2)), mul(a5, 28)), mul(a6, 13)), mul(a7, 13)), mul(a8, 39)), mul(a9, 18)), mul(a10, 34)), mul(a11, 20)), 4378616569090929672)
        mstore(0x20, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2775682836505894372966), mul(a1, 3163723525136951726688)), mul(a2, 2745279249951904274568)), mul(a3, 2644856887556358422425)), mul(a4, 3055863187663592235975)), mul(a5, 2700309066765812663417)), mul(a6, 2543446851391669904336)), mul(a7, 3023867431088977357992)), mul(a8, 2254895971537593352880)), mul(a9, 2632439675356643809393)), mul(a10, 2687089387741105269361)), mul(a11, 2770684487847952940495)), 1680081942362368183024953175845490874821))
        mstore(0x40, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2266351575020573982622), mul(a1, 1614206966658491640694)), mul(a2, 1884864828860779459753)), mul(a3, 2137185812511845740804)), mul(a4, 2000877715239527144020)), mul(a5, 1672515626586444631905)), mul(a6, 2215037799006494895980)), mul(a7, 2082314939965004056246)), mul(a8, 1597832894104549247841)), mul(a9, 2002488951499537540978)), mul(a10, 1896383595174683238464)), mul(a11, 2170580553797496908373)), 1148632164998711646521685716351655751233))
        mstore(0x60, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2023710555265127240363), mul(a1, 2019512295906108172723)), mul(a2, 1807392959282333167323)), mul(a3, 2088534712019844695288)), mul(a4, 2087575094133513400134)), mul(a5, 1817725086442685081062)), mul(a6, 2551955162997235582631)), mul(a7, 2169036384974745952473)), mul(a8, 1990087404064690559841)), mul(a9, 2159343076969803691254)), mul(a10, 1928701975221879203694)), mul(a11, 2281951538037766707294)), 1122732543924552981651475781730842632612))
        mstore(0x80, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2126450438008878006088), mul(a1, 1447096291382798039999)), mul(a2, 1989810228849023769006)), mul(a3, 1860837440717520908480)), mul(a4, 2005439321384389048523)), mul(a5, 1785241796318472637292)), mul(a6, 1828707542969890320848)), mul(a7, 1907936984502144047451)), mul(a8, 1688027815991677288388)), mul(a9, 2119214612550592650088)), mul(a10, 1487152429688061741915)), mul(a11, 1996641554565789172386)), 1114061577485464661034950690537714887101))
        mstore(0xa0, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 1642232433999266311319), mul(a1, 2202105549819228115816)), mul(a2, 1805978900846005656570)), mul(a3, 1878440704517296870091)), mul(a4, 2241020118105615009860)), mul(a5, 1949707378468561445380)), mul(a6, 1645467532782253366047)), mul(a7, 1880741917873105333934)), mul(a8, 1889490240432729463130)), mul(a9, 1689421039169966760127)), mul(a10, 1787167034854370707110)), mul(a11, 1843275810646443961448)), 1112677994240967651338248354263354862328))
        mstore(0xc0, add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2540291292407993818625), mul(a1, 2755035629526912321999)), mul(a2, 2383612017480269421691)), mul(a3, 2366236959047860756773)), mul(a4, 2789579193661905565419)), mul(a5, 2703053840716253421667)), mul(a6, 2513665899568341298751)), mul(a7, 2494017759975324244813)), mul(a8, 2142302192149938254305)), mul(a9, 2330594234164260570779)), mul(a10, 2454845471908884492153)), mul(a11, 2266745690350451139521)), 1368850473161619287451460740305012419410))
        v7 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2431489001244995122644), mul(a1, 2719077753064979758539)), mul(a2, 2188748777293217076957)), mul(a3, 2405267121230216079593)), mul(a4, 2632707452618602254926)), mul(a5, 2342449084935211545462)), mul(a6, 1983630822009084633148)), mul(a7, 2669130397175730233899)), mul(a8, 2283303886192666413959)), mul(a9, 2426467640733366363655)), mul(a10, 2170577716460638408572)), mul(a11, 2349820929446935561318)), 1422058771155993466021756859912687513164)
        v8 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 3046037981350273283710), mul(a1, 3079114456386926537179)), mul(a2, 2770202716826310142702)), mul(a3, 2555001366714269128477)), mul(a4, 3350739764679738976324)), mul(a5, 2688047684826846007889)), mul(a6, 2955599890286636824308)), mul(a7, 2886656160535125461095)), mul(a8, 2835542804508045342968)), mul(a9, 2880785089118340525937)), mul(a10, 2701853989877281348218)), mul(a11, 3092756675802421404617)), 1797593035382164330624779980408418634068)
        v9 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2748246082502495440801), mul(a1, 2916313010273304144845)), mul(a2, 2746933455722416984345)), mul(a3, 2755693147585438299281)), mul(a4, 2923936248102560814897)), mul(a5, 2552841073785532754161)), mul(a6, 2476917423464348262699)), mul(a7, 2690097443571538580215)), mul(a8, 2358899530591714685147)), mul(a9, 2881744707004671821091)), mul(a10, 2266313020997747831051)), mul(a11, 2681750375695187591067)), 1669817489864485520788165786243315933085)
        v10 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2683041837935549293024), mul(a1, 3054912750270641723677)), mul(a2, 2390580971039466106470)), mul(a3, 2488679038750612803851)), mul(a4, 2880883181242797648628)), mul(a5, 2373216217987362920167)), mul(a6, 2807887131076804861074)), mul(a7, 2672975872108491119657)), mul(a8, 2395638598376144624068)), mul(a9, 2545262722058916540163)), mul(a10, 2419820406873802405062)), mul(a11, 2284110648216539666543)), 1485791914894049700392466062655401404322)
        v11 := add(add(add(add(add(add(add(add(add(add(add(add(mul(a0, 2156246729795331684353), mul(a1, 2166316365458004963062)), mul(a2, 1689853689133962483923)), mul(a3, 1938635574594331175832)), mul(a4, 1935416324083222309277)), mul(a5, 2147228686913127644588)), mul(a6, 2349207259999791466937)), mul(a7, 2128318573541569778532)), mul(a8, 1889818149048748063703)), mul(a9, 1927278575559035251118)), mul(a10, 1964695103977368742793)), mul(a11, 2167599345388564173354)), 1049549843480833910770869269283322551164)
      }

      // --- load the init-layer output (scratch 0x180..) into stack registers for the partial rounds ---
      let v1 := mload(0x20)
      let v2 := mload(0x40)
      let v3 := mload(0x60)
      let v4 := mload(0x80)
      let v5 := mload(0xa0)
      let v6 := mload(0xc0)

      // --- partial rounds 0..10: S-box(lane0)+RC, rank-1 mix. Constants are PGStage1._pr0.._pr10.
      //     Deferred-reduction (mirrors Stage2): lanes 1..11 use add(v_j, mul(s0,w_j)) instead of
      //     addmod across rounds 0..9, carrying the TRUE integer (no per-round mod). The S-box round
      //     constant is ALSO deferred: s0 := add(x^7 mod p, RC) (NOT addmod), so s0 = (x^7 mod p)+RC is
      //     the true integer < p+p = 2p < 2^65. s0 only ever feeds mul(s0,.) terms that are reduced mod p
      //     downstream (lanes at round 10, lane0 via next S-box mulmod), and s0 ≡ solc's reduced s0 mod p,
      //     so this stays bit-exact. Bound: s0<2^65 and w_j<2^64, so each increment mul(s0,w_j)<2^129;
      //     after r deferred rounds v_j < init-out(<2^141) + 10*2^129 < 2^142. In d := s0*25 + sum
      //     mul(v_j,coef_j), coef_j<2^64 so each term <2^206, sum of 11 < 2^210 << 2^256 (no truncation).
      //     lane0 is ALSO deferred: rounds 0..9 do v0 := d (unreduced, <2^210) since the next S-box is
      //     mulmod(v0,v0,p) which reduces internally; only round 10 does v0 := mod(d,p) so all 12 lanes
      //     are canonical < 2^64 at the final pack. Round 10 keeps addmod on lanes 1..11 for the same
      //     reason (v_j<2^142 + mul(s0,w_j)<2^129 => sum<2^143, addmod exact). Bit-exact vs solc. ---
      { // partial round 0
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 8415871462856204715) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 4438751076270498736))
        d := add(d, mul(v2, 9317528645525775657))
        d := add(d, mul(v3, 2603614750616077704))
        d := add(d, mul(v4, 9834445229934519080))
        d := add(d, mul(v5, 11955300617986087719))
        d := add(d, mul(v6, 13674383287779636394))
        d := add(d, mul(v7, 7242667852302110551))
        d := add(d, mul(v8, 703710881370165964))
        d := add(d, mul(v9, 5061939192123688976))
        d := add(d, mul(v10, 14416184509556335938))
        d := add(d, mul(v11, 304868360577598380))
        v1 := add(v1, mul(s0, 10702656082108580291))
        v2 := add(v2, mul(s0, 14323272843908492221))
        v3 := add(v3, mul(s0, 15449530374849795087))
        v4 := add(v4, mul(s0, 839422581341380592))
        v5 := add(v5, mul(s0, 11044529172588201887))
        v6 := add(v6, mul(s0, 9218907426627144627))
        v7 := add(v7, mul(s0, 16863852725141286670))
        v8 := add(v8, mul(s0, 12378944184369265821))
        v9 := add(v9, mul(s0, 4291107264489923137))
        v10 := add(v10, mul(s0, 18105902022777689401))
        v11 := add(v11, mul(s0, 4532874245444204412))
        v0 := d
      }
      { // partial round 1
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 15156192896528938595) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 7437226027186543243))
        d := add(d, mul(v2, 15353050892319980048))
        d := add(d, mul(v3, 3199984117275729523))
        d := add(d, mul(v4, 11990763268329609629))
        d := add(d, mul(v5, 5577680852675862792))
        d := add(d, mul(v6, 17892201254274048377))
        d := add(d, mul(v7, 4681998189446302081))
        d := add(d, mul(v8, 6822112447852802370))
        d := add(d, mul(v9, 7318824523402736059))
        d := add(d, mul(v10, 63486289239724471))
        d := add(d, mul(v11, 9953444262837494154))
        v1 := add(v1, mul(s0, 783331064993138470))
        v2 := add(v2, mul(s0, 11780280264626300249))
        v3 := add(v3, mul(s0, 14317347280917240576))
        v4 := add(v4, mul(s0, 7639896796391275580))
        v5 := add(v5, mul(s0, 5524721098652169327))
        v6 := add(v6, mul(s0, 4647621086109661393))
        v7 := add(v7, mul(s0, 551557749415629519))
        v8 := add(v8, mul(s0, 4774730083352601242))
        v9 := add(v9, mul(s0, 9878226461889807280))
        v10 := add(v10, mul(s0, 2796688701546052437))
        v11 := add(v11, mul(s0, 3152254583822593203))
        v0 := d
      }
      { // partial round 2
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 7115538620563575164) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 2317103059171007623))
        d := add(d, mul(v2, 16480286982765085951))
        d := add(d, mul(v3, 13705213611198486247))
        d := add(d, mul(v4, 10236515677047503770))
        d := add(d, mul(v5, 6341681382391377123))
        d := add(d, mul(v6, 6362787076607341484))
        d := add(d, mul(v7, 10057473295910894055))
        d := add(d, mul(v8, 12586789805515730111))
        d := add(d, mul(v9, 4352300357074435274))
        d := add(d, mul(v10, 15739906440350539774))
        d := add(d, mul(v11, 16786966705537008710))
        v1 := add(v1, mul(s0, 5195684422952000615))
        v2 := add(v2, mul(s0, 16386310079584461432))
        v3 := add(v3, mul(s0, 8354845848262314988))
        v4 := add(v4, mul(s0, 6700373425673846218))
        v5 := add(v5, mul(s0, 14613275276996917774))
        v6 := add(v6, mul(s0, 15810393896142816349))
        v7 := add(v7, mul(s0, 8919907675614209581))
        v8 := add(v8, mul(s0, 4378937399360000942))
        v9 := add(v9, mul(s0, 3921314266986613083))
        v10 := add(v10, mul(s0, 3157453341478075556))
        v11 := add(v11, mul(s0, 12056705871081879759))
        v0 := d
      }
      { // partial round 3
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 15396535437187948468) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 14247238213840877673))
        d := add(d, mul(v2, 4982197628621364471))
        d := add(d, mul(v3, 1650209613801527344))
        d := add(d, mul(v4, 16334009413005742380))
        d := add(d, mul(v5, 320004518447392347))
        d := add(d, mul(v6, 7777559975827687149))
        d := add(d, mul(v7, 1266186313330142639))
        d := add(d, mul(v8, 12735743610080455214))
        d := add(d, mul(v9, 9621059894918028247))
        d := add(d, mul(v10, 4350447204024668858))
        d := add(d, mul(v11, 11420240845800225374))
        v1 := add(v1, mul(s0, 12838957912943317144))
        v2 := add(v2, mul(s0, 11392036161259909092))
        v3 := add(v3, mul(s0, 5420611346845318460))
        v4 := add(v4, mul(s0, 11418874531271499277))
        v5 := add(v5, mul(s0, 14582096517505941837))
        v6 := add(v6, mul(s0, 877280106856758747))
        v7 := add(v7, mul(s0, 11091271673331452926))
        v8 := add(v8, mul(s0, 9617340340155417663))
        v9 := add(v9, mul(s0, 9043411348035541157))
        v10 := add(v10, mul(s0, 16964047224456307403))
        v11 := add(v11, mul(s0, 10338102439110648229))
        v0 := d
      }
      { // partial round 4
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 13402196712199986140) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 1701204778899409548))
        d := add(d, mul(v2, 12463216732586668885))
        d := add(d, mul(v3, 7392209094895994703))
        d := add(d, mul(v4, 15680934805691729401))
        d := add(d, mul(v5, 14004357016008534075))
        d := add(d, mul(v6, 14936251243935649556))
        d := add(d, mul(v7, 1522896783411827638))
        d := add(d, mul(v8, 13858466054557097275))
        d := add(d, mul(v9, 3172936841377972450))
        d := add(d, mul(v10, 1068421630679369146))
        d := add(d, mul(v11, 14424837255543781072))
        v1 := add(v1, mul(s0, 1277502887239453738))
        v2 := add(v2, mul(s0, 11492475458589769996))
        v3 := add(v3, mul(s0, 12115111105137538533))
        v4 := add(v4, mul(s0, 6007394463725400498))
        v5 := add(v5, mul(s0, 4633777909023327008))
        v6 := add(v6, mul(s0, 12045217224929432404))
        v7 := add(v7, mul(s0, 5600645681481758769))
        v8 := add(v8, mul(s0, 13058511211226185597))
        v9 := add(v9, mul(s0, 10831228388201534917))
        v10 := add(v10, mul(s0, 10765285645335338967))
        v11 := add(v11, mul(s0, 12314041551985486068))
        v0 := d
      }
      { // partial round 5
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 16375052485106733288) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 10714170731680699852))
        d := add(d, mul(v2, 5765613494791770423))
        d := add(d, mul(v3, 9663820292401160995))
        d := add(d, mul(v4, 397172480378586284))
        d := add(d, mul(v5, 4280709209124899452))
        d := add(d, mul(v6, 1203358955785565947))
        d := add(d, mul(v7, 11202700275482992172))
        d := add(d, mul(v8, 13685583713509618195))
        d := add(d, mul(v9, 3469864161577330170))
        d := add(d, mul(v10, 8734130268423889220))
        d := add(d, mul(v11, 16917450195693745928))
        v1 := add(v1, mul(s0, 4032097614937144430))
        v2 := add(v2, mul(s0, 5682426829072761065))
        v3 := add(v3, mul(s0, 14144004233890775432))
        v4 := add(v4, mul(s0, 11476034762570105656))
        v5 := add(v5, mul(s0, 11441392943423295273))
        v6 := add(v6, mul(s0, 14245661866930276468))
        v7 := add(v7, mul(s0, 11536287954985758398))
        v8 := add(v8, mul(s0, 6483617259986966714))
        v9 := add(v9, mul(s0, 10087111781120039554))
        v10 := add(v10, mul(s0, 13728844829744097141))
        v11 := add(v11, mul(s0, 14679689325173586623))
        v0 := d
      }
      { // partial round 6
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 1054611198573910171) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 8180410513952497551))
        d := add(d, mul(v2, 7071292797447000945))
        d := add(d, mul(v3, 14180677607572215618))
        d := add(d, mul(v4, 6192821375005245090))
        d := add(d, mul(v5, 11618722403488968531))
        d := add(d, mul(v6, 16359132914868028498))
        d := add(d, mul(v7, 629739239384523563))
        d := add(d, mul(v8, 14807849520380455651))
        d := add(d, mul(v9, 9453790714124186574))
        d := add(d, mul(v10, 13094671554168529902))
        d := add(d, mul(v11, 7712187332553607807))
        v1 := add(v1, mul(s0, 6304928008866363842))
        v2 := add(v2, mul(s0, 9855321538770560945))
        v3 := add(v3, mul(s0, 9435164398075715846))
        v4 := add(v4, mul(s0, 9404592978128123150))
        v5 := add(v5, mul(s0, 11002422368171462947))
        v6 := add(v6, mul(s0, 8486311906590791617))
        v7 := add(v7, mul(s0, 18361824531704888434))
        v8 := add(v8, mul(s0, 2798920999004265189))
        v9 := add(v9, mul(s0, 17909793464802401204))
        v10 := add(v10, mul(s0, 5756303597132403312))
        v11 := add(v11, mul(s0, 5858421860645672190))
        v0 := d
      }
      { // partial round 7
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 14596485233396387590) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 17023513964361815961))
        d := add(d, mul(v2, 4047391151444874101))
        d := add(d, mul(v3, 4322167285472126322))
        d := add(d, mul(v4, 5857702128726293638))
        d := add(d, mul(v5, 5139199894843344198))
        d := add(d, mul(v6, 1693515656102034708))
        d := add(d, mul(v7, 12470471516364544231))
        d := add(d, mul(v8, 8323866952084077697))
        d := add(d, mul(v9, 12651873977826689095))
        d := add(d, mul(v10, 5067670011142229746))
        d := add(d, mul(v11, 396279522907796927))
        v1 := add(v1, mul(s0, 17305709116193116427))
        v2 := add(v2, mul(s0, 735829306202841815))
        v3 := add(v3, mul(s0, 14847743950994388316))
        v4 := add(v4, mul(s0, 11139080626411756670))
        v5 := add(v5, mul(s0, 7092455469264931963))
        v6 := add(v6, mul(s0, 11583767394161657005))
        v7 := add(v7, mul(s0, 15774934118411863340))
        v8 := add(v8, mul(s0, 4416857554682544229))
        v9 := add(v9, mul(s0, 9159855784268361426))
        v10 := add(v10, mul(s0, 8216101670692368083))
        v11 := add(v11, mul(s0, 16367782717227750410))
        v0 := d
      }
      { // partial round 8
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 13680159589485875108) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 16390401751368131934))
        d := add(d, mul(v2, 7418420403566340092))
        d := add(d, mul(v3, 8653653352406274042))
        d := add(d, mul(v4, 4118931406823846491))
        d := add(d, mul(v5, 82975984786450442))
        d := add(d, mul(v6, 18222397316657226499))
        d := add(d, mul(v7, 2002174628128864983))
        d := add(d, mul(v8, 9634468324007960767))
        d := add(d, mul(v9, 3259584970126823840))
        d := add(d, mul(v10, 581370729274350312))
        d := add(d, mul(v11, 17755967144133734705))
        v1 := add(v1, mul(s0, 12329937970340684597))
        v2 := add(v2, mul(s0, 10602297383654186753))
        v3 := add(v3, mul(s0, 5891764497626072293))
        v4 := add(v4, mul(s0, 10671154149112267313))
        v5 := add(v5, mul(s0, 18234822653119242373))
        v6 := add(v6, mul(s0, 15287378323692558105))
        v7 := add(v7, mul(s0, 9967103142034849899))
        v8 := add(v8, mul(s0, 15861939895842675328))
        v9 := add(v9, mul(s0, 11730063476303470848))
        v10 := add(v10, mul(s0, 1586390848658847158))
        v11 := add(v11, mul(s0, 1015360682565850373))
        v0 := d
      }
      { // partial round 9
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 9441690674504273278) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 9071247654034188589))
        d := add(d, mul(v2, 6594541173975452315))
        d := add(d, mul(v3, 17782188089785283344))
        d := add(d, mul(v4, 3595742487221932055))
        d := add(d, mul(v5, 9841642201692265487))
        d := add(d, mul(v6, 1029671011456985627))
        d := add(d, mul(v7, 13457875495926821529))
        d := add(d, mul(v8, 6870405007338730846))
        d := add(d, mul(v9, 12744130097658441846))
        d := add(d, mul(v10, 6788288399186088634))
        d := add(d, mul(v11, 357912856529587295))
        v1 := add(v1, mul(s0, 4417656488067463062))
        v2 := add(v2, mul(s0, 14987770745080868386))
        v3 := add(v3, mul(s0, 4702825855063868377))
        v4 := add(v4, mul(s0, 2465246157933796197))
        v5 := add(v5, mul(s0, 8034369030882576822))
        v6 := add(v6, mul(s0, 15698764330557579947))
        v7 := add(v7, mul(s0, 11839103375501390181))
        v8 := add(v8, mul(s0, 4595990697051972631))
        v9 := add(v9, mul(s0, 14148213542088135280))
        v10 := add(v10, mul(s0, 14849248616009699298))
        v11 := add(v11, mul(s0, 15807262764748562013))
        v0 := d
      }
      { // partial round 10
        let s0 { let x2 := mulmod(v0, v0, p) s0 := add(mulmod(mulmod(x2, v0, p), mulmod(x2, x2, p), p), 7281057872237841107) }
        let d := mul(s0, 25)
        d := add(d, mul(v1, 5607434777391338218))
        d := add(d, mul(v2, 15814876086124552425))
        d := add(d, mul(v3, 10566177234457318078))
        d := add(d, mul(v4, 15354864780205183334))
        d := add(d, mul(v5, 15216311397122257089))
        d := add(d, mul(v6, 2674093911898978557))
        d := add(d, mul(v7, 16268280753066444837))
        d := add(d, mul(v8, 3675451000502615243))
        d := add(d, mul(v9, 701273502091366776))
        d := add(d, mul(v10, 15854278682598134666))
        d := add(d, mul(v11, 6924615965242507246))
        v1 := addmod(v1, mul(s0, 1262098398535043837), p)
        v2 := addmod(v2, mul(s0, 2436065499532941641), p)
        v3 := addmod(v3, mul(s0, 1138970283407778564), p)
        v4 := addmod(v4, mul(s0, 1825502889302643134), p)
        v5 := addmod(v5, mul(s0, 5500855066099563465), p)
        v6 := addmod(v6, mul(s0, 11666892062115297604), p)
        v7 := addmod(v7, mul(s0, 13463068267332421729), p)
        v8 := addmod(v8, mul(s0, 17516970128403465337), p)
        v9 := addmod(v9, mul(s0, 11088428730628824449), p)
        v10 := addmod(v10, mul(s0, 4615288675764694853), p)
        v11 := addmod(v11, mul(s0, 16220123440754855385), p)
        v0 := mod(d, p)
      }

      // --- pack 12 reduced lanes -> 3 return words (4 lanes/word, low limb first) ---
      mstore(0x00, or(or(v0, shl(64, v1)), or(shl(128, v2), shl(192, v3))))
      mstore(0x20, or(or(v4, shl(64, v5)), or(shl(128, v6), shl(192, v7))))
      mstore(0x40, or(or(v8, shl(64, v9)), or(shl(128, v10), shl(192, v11))))
      return(0, 96)
      }

    }
  }
}
