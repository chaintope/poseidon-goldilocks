// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {PGStage1} from "../src/PoseidonGoldilocks.sol";

/// @title Regression test for the hand-written Yul re-implementation of PGStage1.
/// @notice Source: yul/Stage1.yul, compiled by `yul/build.sh 1`
///         (solc --strict-assembly --optimize --yul-optimizations "dhfoDgvulfnTUtnIf") into
///         yul/Stage1.hex, which is READ FROM DISK AT RUNTIME here (mirrors test/YulStage2Base.sol) so
///         re-running `build.sh 1` is enough — no bytecode is pasted into the tests.
/// Asserts: (1) bit-exact vs the solc PGStage1 for the permZero-derived input,
///          (2) a differential FUZZ (>=256 runs) over random valid 12-lane inputs is word-for-word equal,
///          (3) the Yul stage stays under EIP-170 and below the solc PGStage1 size.
contract YulStage1Test is Test {
    /// Path (relative to the foundry project root) to the hand-written Yul PGStage1 creation bytecode.
    string internal constant YUL_PGSTAGE1_PATH = "yul/Stage1.hex";
    /// solc PGStage1 deployed runtime size (out/PoseidonGoldilocks.sol/PGStage1.json) — the size ceiling.
    uint256 internal constant SOLC_PGSTAGE1_SIZE = 13831;

    address yul;

    function setUp() public {
        bytes memory c = _yulPGStage1(); // read from yul/Stage1.hex
        address a;
        assembly {
            a := create(0, add(c, 0x20), mload(c))
        }
        require(a != address(0), "yul stage1 deploy failed");
        yul = a;
    }

    /// Read + decode the Yul PGStage1 creation bytecode from disk (single `0x...` line, trim newline).
    function _yulPGStage1() internal view returns (bytes memory) {
        return vm.parseBytes(_trimWhitespace(vm.readFile(YUL_PGSTAGE1_PATH)));
    }

    function _yulRun(uint256 w0, uint256 w1, uint256 w2) internal returns (uint256, uint256, uint256) {
        (bool ok, bytes memory ret) =
            yul.delegatecall(abi.encodeWithSignature("run(uint256,uint256,uint256)", w0, w1, w2));
        require(ok, "yul run failed");
        return abi.decode(ret, (uint256, uint256, uint256));
    }

    /// Yul stage1 must reproduce the solc stage1 exactly for the permute([0;12]) starting state.
    function test_YulStage1_BitExact() public {
        (uint256 s0, uint256 s1, uint256 s2) = PGStage1.run(0, 0, 0);
        (uint256 y0, uint256 y1, uint256 y2) = _yulRun(0, 0, 0);
        assertEq(y0, s0, "word0 != solc");
        assertEq(y1, s1, "word1 != solc");
        assertEq(y2, s2, "word2 != solc");
    }

    /// Differential fuzz: for ANY valid 12-lane input (each lane a Goldilocks element < p), the
    /// hand-written Yul must reproduce the solc PGStage1 word-for-word. Foundry's default fuzz runs
    /// (>=256) exercises the unreduced full-round + deferred init/partial bounds.
    function testFuzz_YulStage1_MatchesSolc(uint256 seed) public {
        uint256 P = 0xFFFFFFFF00000001;
        uint256[12] memory l;
        for (uint256 i = 0; i < 12; i++) {
            l[i] = uint256(keccak256(abi.encode(seed, i))) % P; // canonical field element < p
        }
        // pack 12 lanes -> 3 words (4 lanes/word, low limb first) — the stage's ABI convention
        uint256 w0 = l[0] | (l[1] << 64) | (l[2] << 128) | (l[3] << 192);
        uint256 w1 = l[4] | (l[5] << 64) | (l[6] << 128) | (l[7] << 192);
        uint256 w2 = l[8] | (l[9] << 64) | (l[10] << 128) | (l[11] << 192);
        (uint256 s0, uint256 s1, uint256 s2) = PGStage1.run(w0, w1, w2);
        (uint256 y0, uint256 y1, uint256 y2) = _yulRun(w0, w1, w2);
        assertEq(y0, s0, "fuzz: word0 != solc");
        assertEq(y1, s1, "fuzz: word1 != solc");
        assertEq(y2, s2, "fuzz: word2 != solc");
    }

    /// Deployed Yul stays well under EIP-170 and below the solc stage size.
    function test_YulStage1_Size() public view {
        uint256 sz = yul.code.length;
        console2.log("yul PGStage1 runtime size:", sz);
        assertLt(sz, 24576, "exceeds EIP-170");
        assertLt(sz, SOLC_PGSTAGE1_SIZE, "not smaller than solc PGStage1");
    }

    /// Measure the Yul stage1 gas (baseline for the optimization log) alongside the solc stage.
    function test_YulStage1_Gas() public {
        PGStage1.run(0, 0, 0); // warm
        _yulRun(0, 0, 0);

        uint256 g1 = gasleft();
        PGStage1.run(0, 0, 0);
        uint256 gSolc = g1 - gasleft();
        uint256 g2 = gasleft();
        _yulRun(0, 0, 0);
        uint256 gYul = g2 - gasleft();

        console2.log("solc stage1 gas:", gSolc);
        console2.log("yul  stage1 gas:", gYul);
    }

    /// Inverse-drift guard (mirrors test_Stage2HexMatchesYulSource). The suite reads yul/Stage1.hex,
    /// not the yul/Stage1.yul source — so editing the .yul and forgetting to re-run `yul/build.sh 1`
    /// would leave everything validating STALE bytecode. This recompiles Stage1.yul (via `build.sh 1`,
    /// to a temp) and asserts byte-equality with the committed Stage1.hex. Needs ffi=true (foundry.toml);
    /// skips cleanly when the pinned solc is absent (set SOLC=) so it never false-fails in CI.
    function test_Stage1HexMatchesYulSource() public {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "SOLC=\"${SOLC:-$HOME/.local/share/svm/0.8.24/solc-0.8.24}\";"
            " if [ ! -x \"$SOLC\" ]; then printf SKIP; exit 0; fi;"
            " if OUT=/tmp/stage1_driftcheck.hex bash yul/build.sh 1 >/dev/null 2>&1 &&"
            " diff -q /tmp/stage1_driftcheck.hex yul/Stage1.hex >/dev/null 2>&1;"
            " then printf MATCH; else printf STALE; fi";
        bytes memory out = vm.ffi(cmd);
        if (keccak256(out) == keccak256(bytes("SKIP"))) {
            emit log("test_Stage1HexMatchesYulSource SKIPPED: pinned solc not found (set SOLC= to enable)");
            return;
        }
        assertEq(
            string(out), "MATCH", "yul/Stage1.hex is STALE -- re-run `yul/build.sh 1` after editing yul/Stage1.yul"
        );
    }

    /// Strip trailing ASCII whitespace so vm.parseBytes sees a clean `0x...` string.
    function _trimWhitespace(string memory s) private pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 end = b.length;
        while (end > 0) {
            bytes1 ch = b[end - 1];
            if (ch == 0x0a || ch == 0x0d || ch == 0x20 || ch == 0x09) {
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
