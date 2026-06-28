// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// Shared test base for the hand-written Yul Poseidon stages. It reads the production creation bytecode
/// from `yul/Stage1.hex` / `yul/Stage2.hex` AT RUNTIME, never baked in as a literal — a baked-in copy
/// could silently drift from the .hex after a Yul rebuild (`yul/build.sh`),
/// letting tests pass against stale bytecode. Requires the fs read permission for both hex files in
/// foundry.toml.
///
/// NOTE: this is the Poseidon-only extraction of the original pod2_playground base. The registry-linking
/// helpers (`_useYulStages` etc., which etched the Yul over the solc libraries linked into
/// Pod2RegistrySMT) were dropped here because that SMT contract is not part of the Poseidon hash. The
/// Stage1/Stage2 regression tests deploy the Yul builds directly and diff them against the solc PGStage1
/// / PGStage2 libraries in src/PoseidonGoldilocks.sol — no registry needed.
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
