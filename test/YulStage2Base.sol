// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoseidonGoldilocks} from "../src/PoseidonGoldilocks.sol";

/// Shared test base for the hand-written Yul Poseidon stages. It reads the production creation bytecode
/// from `yul/Stage1.hex` / `yul/Stage2.hex` AT RUNTIME, never baked in as a literal — a baked-in copy
/// could silently drift from the .hex after a Yul rebuild (`yul/build.sh`),
/// letting tests pass against stale bytecode. Requires the fs read permission for both hex files in
/// foundry.toml.
///
/// The Stage1/Stage2 regression tests deploy the Yul builds directly and diff them against the solc
/// PGStage1 / PGStage2 reference libraries in test/ref/PoseidonRef.sol.
abstract contract YulStage2Base is Test {
    /// Path (relative to the foundry project root) to the hand-written Yul PGStage2 creation bytecode.
    string internal constant YUL_PGSTAGE2_PATH = "yul/Stage2.hex";
    /// Path to the hand-written Yul PGStage1 creation bytecode.
    string internal constant YUL_PGSTAGE1_PATH = "yul/Stage1.hex";

    /// Read + decode the production Yul PGStage2 creation bytecode from disk. The file is a single
    /// `0x...` line (build.sh output) usually with a trailing newline, so trim before parsing.
    function _yulPGStage2() internal view returns (bytes memory) {
        return vm.parseBytes(_trimWhitespace(vm.readFile(YUL_PGSTAGE2_PATH)));
    }

    /// Read the production Yul PGStage1 creation bytecode from yul/Stage1.hex.
    function _yulPGStage1() internal view returns (bytes memory) {
        return vm.parseBytes(_trimWhitespace(vm.readFile(YUL_PGSTAGE1_PATH)));
    }

    /// Deploy a single Yul stage from its creation bytecode.
    function _deployYulStage(bytes memory code) internal returns (address a) {
        assembly {
            a := create(0, add(code, 0x20), mload(code))
        }
        require(a != address(0), "yul stage deploy failed");
    }

    /// Deploy both Yul stages from the committed .hex and wire them into a PoseidonGoldilocks contract —
    /// the EXACT production configuration (the same bytecode script/Deploy.s.sol ships).
    function _deployPoseidon() internal returns (PoseidonGoldilocks) {
        address s1 = _deployYulStage(_yulPGStage1());
        address s2 = _deployYulStage(_yulPGStage2());
        return new PoseidonGoldilocks(s1, s2);
    }

    /// Strip trailing ASCII whitespace (\n, \r, space, tab) so vm.parseBytes sees a clean `0x...` string.
    function _trimWhitespace(string memory s) private pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 end = b.length;
        while (end > 0) {
            bytes1 c = b[end - 1];
            if (c == 0x0a || c == 0x0d || c == 0x20 || c == 0x09) {
                end--;
            } else {
                break;
            }
        }
        bytes memory out = new bytes(end);
        for (uint256 i = 0; i < end; i++) {
            out[i] = b[i];
        }
        return string(out);
    }
}
