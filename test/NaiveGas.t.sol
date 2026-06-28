// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {PoseidonGoldilocksConstants, PoseidonConstants} from "../src/PoseidonGoldilocksConstants.sol";

/// @title Naive plain-Solidity Poseidon-Goldilocks — gas baseline reference.
/// @notice "The first thing you'd write": no assembly, `addmod`/`mulmod`, straightforward loops, a full
///         12x12 MDS every round (no fast-partial-round trick), constants loaded from the packed table.
///         It mirrors reference/poseidon_reference.py exactly and is asserted against plonky2's official
///         vector. Kept so anyone can reproduce the ~1.97M-gas baseline that motivated the Yul rewrite:
///
///             forge test --match-contract NaiveGasTest -vv
///
///         Compare against the production figures in test/Poseidon.t.sol (Yul, ~35k) and the README
///         Gas table. This contract is a baseline ONLY — never deployed in production.
contract NaivePoseidon {
    uint256 constant P = 0xFFFFFFFF00000001;

    /// S-box: x^7 over Goldilocks.
    function _sbox(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, P);
        uint256 x4 = mulmod(x2, x2, P);
        uint256 x6 = mulmod(x4, x2, P);
        return mulmod(x6, x, P);
    }

    /// Full 12x12 circulant MDS + diagonal, exactly as the Python reference does it.
    function _mds(uint256[12] memory st) internal pure returns (uint256[12] memory out) {
        uint8[12] memory CIRC = [17, 15, 41, 16, 2, 28, 13, 13, 39, 18, 34, 20];
        for (uint256 r = 0; r < 12; r++) {
            uint256 s = 0;
            for (uint256 i = 0; i < 12; i++) {
                s = addmod(s, mulmod(st[(i + r) % 12], CIRC[i], P), P);
            }
            if (r == 0) {
                s = addmod(s, mulmod(st[0], 8, P), P); // DIAG = [8,0,...,0]
            }
            out[r] = s;
        }
    }

    /// 30 rounds: full x4 -> partial x22 -> full x4.
    function permute(uint256[12] memory st) external pure returns (uint256[12] memory) {
        uint256[360] memory arc = PoseidonGoldilocksConstants.load().arc;
        for (uint256 i = 0; i < 12; i++) {
            st[i] = st[i] % P;
        }
        uint256 rc = 0;
        for (uint256 k = 0; k < 4; k++) {
            for (uint256 i = 0; i < 12; i++) {
                st[i] = addmod(st[i], arc[12 * rc + i], P);
            }
            for (uint256 i = 0; i < 12; i++) {
                st[i] = _sbox(st[i]);
            }
            st = _mds(st);
            rc++;
        }
        for (uint256 k = 0; k < 22; k++) {
            for (uint256 i = 0; i < 12; i++) {
                st[i] = addmod(st[i], arc[12 * rc + i], P);
            }
            st[0] = _sbox(st[0]);
            st = _mds(st);
            rc++;
        }
        for (uint256 k = 0; k < 4; k++) {
            for (uint256 i = 0; i < 12; i++) {
                st[i] = addmod(st[i], arc[12 * rc + i], P);
            }
            for (uint256 i = 0; i < 12; i++) {
                st[i] = _sbox(st[i]);
            }
            st = _mds(st);
            rc++;
        }
        return st;
    }
}

contract NaiveGasTest is Test {
    NaivePoseidon naive;

    function setUp() public {
        naive = new NaivePoseidon();
    }

    /// Assert the naive impl is correct (plonky2 vector) and print its permute gas (the baseline).
    function test_NaiveGas() public {
        uint256[12] memory zero;
        uint256[12] memory r = naive.permute(zero);
        assertEq(r[0], 0x3c18a9786cb0b359, "naive impl != plonky2 vector");

        naive.permute(zero); // warm
        uint256 g0 = gasleft();
        naive.permute(zero);
        uint256 used = g0 - gasleft();
        console2.log("NAIVE plain-Solidity permute gas:", used);
    }
}
