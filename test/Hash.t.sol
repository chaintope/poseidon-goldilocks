// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

import {PoseidonGoldilocks} from "../src/PoseidonGoldilocks.sol";
import {YulStage2Base} from "./YulStage2Base.sol";

/// @title Fixed-width hash (hash_with_flag) test (production Yul configuration).
/// @notice Deploys the Yul stages + PoseidonGoldilocks contract (the production config) and checks
///         hashWithFlag against vectors produced by reference/poseidon_reference.py, which itself
///         self-checks against plonky2's official permute([0;12]) vector. flag=1 is the KV/leaf hash,
///         flag=2 the node hash. Run `python3 reference/poseidon_reference.py` to regenerate.
contract HashTest is YulStage2Base {
    PoseidonGoldilocks h;

    function setUp() public {
        h = _deployPoseidon();
    }

    /// KV (leaf) hash, flag=1, inputs = key[1,2,3,4] ++ value[5,6,7,8].
    /// Reference: KV_1_8.
    function test_KvHash_MatchesReference() public view {
        uint256[8] memory inputs = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory got = h.hashWithFlag(1, inputs);
        uint256[4] memory exp = [
            uint256(14477923671071086014),
            13530133907603408845,
            530129816956444124,
            3172139877675746571
        ];
        for (uint256 i = 0; i < 4; i++) {
            assertEq(got[i], exp[i], "kv hash mismatch");
        }
    }

    /// Node hash, flag=2, inputs = left[1,2,3,4] ++ right[5,6,7,8].
    /// Reference: NODE_1_8.
    function test_NodeHash_MatchesReference() public view {
        uint256[8] memory inputs = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        uint256[4] memory got = h.hashWithFlag(2, inputs);
        uint256[4] memory exp = [
            uint256(146419687382461335),
            13858957422018903185,
            1939785522703740182,
            3464835132705570690
        ];
        for (uint256 i = 0; i < 4; i++) {
            assertEq(got[i], exp[i], "node hash mismatch");
        }
    }

    /// Single-leaf tree root (kv_hash(key=[0;4], value=[9,0,0,0]), flag=1).
    /// Reference: LEAF_K0_V9.
    function test_LeafK0V9_MatchesReference() public view {
        uint256[8] memory inputs = [uint256(0), 0, 0, 0, 9, 0, 0, 0];
        uint256[4] memory got = h.hashWithFlag(1, inputs);
        uint256[4] memory exp = [
            uint256(18108696077686724440),
            16891710740054774891,
            12072568860301855986,
            7876490580894929027
        ];
        for (uint256 i = 0; i < 4; i++) {
            assertEq(got[i], exp[i], "leaf hash mismatch");
        }
    }

    /// Inputs are reduced mod p, so adding p to a lane must not change the digest.
    function testFuzz_HashCanonicalizesInputs(uint256 flag, uint256[8] memory inputs) public view {
        uint256 P = 0xFFFFFFFF00000001;
        uint256[8] memory reduced;
        for (uint256 i = 0; i < 8; i++) {
            reduced[i] = inputs[i] % P;
        }
        // bound flag so flag + (raw inputs possibly huge) stays representable; hashWithFlag reduces both.
        uint256[4] memory a = h.hashWithFlag(flag, inputs);
        uint256[4] memory b = h.hashWithFlag(flag % P, reduced);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(a[i], b[i], "canonicalization mismatch");
        }
    }
}
