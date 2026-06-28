// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoseidonGoldilocks} from "../src/PoseidonGoldilocks.sol";

/// @dev Expose the internal library as an external function for testing & gas measurement.
contract Harness {
    function permZero() external pure returns (uint256[12] memory s) {
        s = PoseidonGoldilocks.permute(s); // s starts all-zero
    }

    function permute(uint256[12] memory s) external pure returns (uint256[12] memory) {
        return PoseidonGoldilocks.permute(s);
    }
}

/// @title End-to-end Poseidon-Goldilocks permutation test.
/// @notice Independent anchor: plonky2's official Poseidon-Goldilocks output vector for the all-zero
///         12-lane input. permute([0;12])[0] == 0x3c18a9786cb0b359 (plonky2 rev 109d517d). Extracted
///         from the original pod2_playground test/Pod2SMT.t.sol so the full 30-round permute (solc
///         Stage1 -> Stage2 pipeline) is covered without the SMT registry.
contract PoseidonTest is Test {
    Harness h;

    function setUp() public {
        h = new Harness();
    }

    function test_PermZero_MatchesPlonky2() public view {
        uint256[12] memory got = h.permZero();
        uint256[12] memory exp = [
            uint256(0x3c18a9786cb0b359),
            0xc4055e3364a246c3,
            0x7953db0ab48808f4,
            0xc71603f33a1144ca,
            0xd7709673896996dc,
            0x46a84e87642f44ed,
            0xd032648251ee0b3c,
            0x1c687363b207df62,
            0xdf8565563e8045fe,
            0x40f5b37ff4254dae,
            0xd070f637b431067c,
            0x1792b1c4342109d7
        ];
        for (uint256 i = 0; i < 12; i++) {
            assertEq(got[i], exp[i], "poseidon perm mismatch");
        }
    }

    /// @dev Helper: run permute(input) through the harness and assert it equals plonky2's published output.
    function _checkVector(uint256[12] memory input, uint256[12] memory exp) internal view {
        uint256[12] memory got = h.permute(input);
        for (uint256 i = 0; i < 12; i++) {
            assertEq(got[i], exp[i], "plonky2 vector mismatch");
        }
    }

    /// plonky2 official test vector #2: sequential input [0,1,...,11].
    /// Source: 0xPolygonZero/plonky2 plonky2/src/hash/poseidon_goldilocks.rs test_vectors().
    function test_PermSequential_MatchesPlonky2() public view {
        uint256[12] memory input = [uint256(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
        uint256[12] memory exp = [
            uint256(0xd64e1e3efc5b8e9e),
            0x53666633020aaa47,
            0xd40285597c6a8825,
            0x613a4f81e81231d2,
            0x414754bfebd051f0,
            0xcb1f8980294a023f,
            0x6eb2a9e4d54a9d0f,
            0x1902bc3af467e056,
            0xf045d5eafdc6021f,
            0xe4150f77caaa3be5,
            0xc9bfd01d39b50cce,
            0x5c0a27fcb0e1459b
        ];
        _checkVector(input, exp);
    }

    /// plonky2 official test vector #3: every lane = neg_one = p - 1 = 0xFFFFFFFF00000000.
    /// This is the field-maximum input — the strongest exercise of the deferred-reduction overflow bounds.
    function test_PermNegOne_MatchesPlonky2() public view {
        uint256 negOne = 0xFFFFFFFF00000000; // p - 1
        uint256[12] memory input;
        for (uint256 i = 0; i < 12; i++) {
            input[i] = negOne;
        }
        uint256[12] memory exp = [
            uint256(0xbe0085cfc57a8357),
            0xd95af71847d05c09,
            0xcf55a13d33c1c953,
            0x95803a74f4530e82,
            0xfcd99eb30a135df1,
            0xe095905e913a3029,
            0xde0392461b42919b,
            0x7d3260e24e81d031,
            0x10d3d0465d9deaa0,
            0xa87571083dfc2a47,
            0xe18263681e9958f8,
            0xe28e96f1ae5e60d3
        ];
        _checkVector(input, exp);
    }

    /// plonky2 official test vector #4: 12 pseudorandom field elements.
    function test_PermRandom_MatchesPlonky2() public view {
        uint256[12] memory input = [
            uint256(0x8ccbbbea4fe5d2b7),
            0xc2af59ee9ec49970,
            0x90f7e1a9e658446a,
            0xdcc0630a3ab8b1b8,
            0x7ff8256bca20588c,
            0x5d99a7ca0c44ecfb,
            0x48452b17a70fbee3,
            0xeb09d654690b6c88,
            0x4a55d3a39c676a88,
            0xc0407a38d2285139,
            0xa234bac9356386d1,
            0xe1633f2bad98a52f
        ];
        uint256[12] memory exp = [
            uint256(0xa89280105650c4ec),
            0xab542d53860d12ed,
            0x5704148e9ccab94f,
            0xd3a826d4b62da9f5,
            0x8a7a6ca87892574f,
            0xc7017e1cad1a674e,
            0x1f06668922318e34,
            0xa3b203bc8102676f,
            0xfcc781b0ce382bf2,
            0x934c69ff3ed14ba5,
            0x504688a5996e8f13,
            0x401f3f2ed524a2ba
        ];
        _checkVector(input, exp);
    }
}
