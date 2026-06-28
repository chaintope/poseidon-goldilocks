// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

/// @title Poseidon-Goldilocks (plonky2 compatible), gas-optimized for the EVM.
///
/// THE HASH. Poseidon over the Goldilocks field (p = 2^64 - 2^32 + 1). State = 12 lanes, each a
/// field element < p. The permutation is 30 rounds applied in this fixed order:
///     full x4  ->  partial x22  ->  full x4
/// where every round is:  (1) AddRoundConstants  (2) S-box x^7  (3) MDS linear mixing.
///   - FULL round:    S-box on all 12 lanes.
///   - PARTIAL round: S-box on lane 0 only (cheaper; security comes from the 8 full rounds).
/// The 360 round constants and the 12x12 MDS matrix come from plonky2 (rev 109d517d).
/// permute([0;12])[0] == 0x3c18a9786cb0b359 (plonky2's official test vector) — asserted in
/// test/Poseidon.t.sol. A fixed-width hash on top of permute is exposed as hashWithFlag.
///
/// ARCHITECTURE. The 30 rounds run as TWO hand-written Yul stage contracts (yul/Stage1.yul,
/// yul/Stage2.yul -> Stage1.hex/Stage2.hex), each < EIP-170 24KB and ~2x cheaper than the solc port:
///     Stage1 = full rounds 1-4 + partial-round init + partial rounds 0-10
///     Stage2 = partial rounds 11-21 + full rounds 5-8
/// Both expose `run(uint256,uint256,uint256) -> (uint256,uint256,uint256)` (state packed 4 lanes/word).
/// This contract holds their deployed addresses (immutable) and pipelines Stage1 -> Stage2 by STATICCALL.
/// Deploy with script/Deploy.s.sol (deploys both .hex stages, then this contract). The original solc
/// PGStage1/PGStage2 libraries live in test/ref/PoseidonRef.sol as the differential test oracle only.
contract PoseidonGoldilocks {
    /// Goldilocks prime p = 2^64 - 2^32 + 1.
    uint256 internal constant P = 0xFFFFFFFF00000001;

    /// Deployed yul/Stage1.hex (full 1-4 + partial init + partial 0-10).
    address public immutable stage1;
    /// Deployed yul/Stage2.hex (partial 11-21 + full 5-8).
    address public immutable stage2;

    /// @param _stage1 Address of the deployed Stage1 Yul bytecode (yul/Stage1.hex).
    /// @param _stage2 Address of the deployed Stage2 Yul bytecode (yul/Stage2.hex).
    constructor(address _stage1, address _stage2) {
        require(_stage1 != address(0) && _stage2 != address(0), "stage addr zero");
        require(_stage1.code.length != 0 && _stage2.code.length != 0, "stage not deployed");
        stage1 = _stage1;
        stage2 = _stage2;
    }

    /// @notice Poseidon-Goldilocks permutation. Packs the 12 lanes into 3 words, pipelines the two Yul
    ///         stages (Stage1 -> Stage2) by STATICCALL, then unpacks. Each lane of `s` must be < 2^64.
    function permute(uint256[12] memory s) public view returns (uint256[12] memory) {
        uint256 w0;
        uint256 w1;
        uint256 w2;
        // pack 12 limbs (each < 2^64) into 3 words once, then pipeline the 2 stages as 3 scalars
        // (call marshaling of uint256[12] ~4.1k each -> 3 scalars ~0.7k each).
        assembly ("memory-safe") {
            w0 := or(or(mload(s), shl(64, mload(add(s, 0x20)))), or(shl(128, mload(add(s, 0x40))), shl(192, mload(add(s, 0x60)))))
            w1 := or(or(mload(add(s, 0x80)), shl(64, mload(add(s, 0xa0)))), or(shl(128, mload(add(s, 0xc0))), shl(192, mload(add(s, 0xe0)))))
            w2 := or(or(mload(add(s, 0x100)), shl(64, mload(add(s, 0x120)))), or(shl(128, mload(add(s, 0x140))), shl(192, mload(add(s, 0x160)))))
        }
        (w0, w1, w2) = _runStage(stage1, w0, w1, w2);
        (w0, w1, w2) = _runStage(stage2, w0, w1, w2);
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

    /// STATICCALL one Yul stage with the shared `run(uint256,uint256,uint256)` ABI. The Yul code is pure
    /// (reads only calldata, touches no storage), so a static context is sufficient and safest.
    function _runStage(address stage, uint256 w0, uint256 w1, uint256 w2)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        (bool ok, bytes memory ret) =
            stage.staticcall(abi.encodeWithSignature("run(uint256,uint256,uint256)", w0, w1, w2));
        require(ok, "stage call failed");
        return abi.decode(ret, (uint256, uint256, uint256));
    }

    /// @notice Fixed-width hash: 8 field elements -> 4. Initializes the 12-lane state to `flag` in every
    ///         lane, overwrites the first 8 lanes with the (canonicalized) `inputs`, applies one
    ///         permutation, and returns the first 4 output lanes. Mirrors
    ///         reference/poseidon_reference.py:hash_with_flag.
    /// @param flag    Domain-separation tag written into the state before the inputs (use 0 if not needed).
    /// @param inputs  The 8 field-element inputs (reduced mod p so each lane is a canonical Goldilocks elem).
    /// @return out    The first 4 lanes of the permuted state (the hash digest).
    function hashWithFlag(uint256 flag, uint256[8] memory inputs) public view returns (uint256[4] memory out) {
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
