// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {PGStage1, PGStage2} from "./ref/PoseidonRef.sol";
import {YulStage2Base} from "./YulStage2Base.sol";

/// @title Regression test for the hand-written Yul re-implementation of PGStage2.
/// @notice Source: yul/Stage2.yul, compiled by `yul/build.sh 2`
///         (solc --strict-assembly --optimize --yul-optimizations "dhfoDgvulfnTUtnIf") into
///         yul/Stage2.hex. The base reads that file at runtime, so re-running build.sh is enough —
///         no bytecode is pasted into the tests.
/// Asserts: (1) bit-exact vs the solc PGStage2 and vs the plonky2 permZero vector,
///          (2) the Yul stage is no more expensive than the solc stage.
contract YulStage2Test is YulStage2Base {
    address yul;

    function setUp() public {
        bytes memory c = _yulPGStage2(); // read from yul/Stage2.hex (shared with the production deploy)
        address a;
        assembly {
            a := create(0, add(c, 0x20), mload(c))
        }
        require(a != address(0), "yul stage2 deploy failed");
        yul = a;
    }

    function _yulRun(uint256 w0, uint256 w1, uint256 w2) internal returns (uint256, uint256, uint256) {
        (bool ok, bytes memory ret) =
            yul.delegatecall(abi.encodeWithSignature("run(uint256,uint256,uint256)", w0, w1, w2));
        require(ok, "yul run failed");
        return abi.decode(ret, (uint256, uint256, uint256));
    }

    /// Yul stage2 must reproduce the solc stage2 exactly, and the full permute([0;12])
    /// must hit plonky2's official first-lane vector.
    function test_YulStage2_BitExact() public {
        (uint256 a, uint256 b, uint256 c) = PGStage1.run(0, 0, 0);
        (uint256 s0, uint256 s1, uint256 s2) = PGStage2.run(a, b, c);
        (uint256 y0, uint256 y1, uint256 y2) = _yulRun(a, b, c);
        assertEq(y0, s0, "word0 != solc");
        assertEq(y1, s1, "word1 != solc");
        assertEq(y2, s2, "word2 != solc");
        assertEq(s0 & 0xFFFFFFFFFFFFFFFF, 0x3c18a9786cb0b359, "permZero lane0 != plonky2 vector");
    }

    /// Differential fuzz: for ANY valid 12-lane input (each lane a Goldilocks element < p), the
    /// hand-written Yul must reproduce the solc PGStage2 word-for-word. This is the real guarantee
    /// the deferred-reduction optimizations need — bit-exactness was otherwise only checked for the
    /// single permZero-derived input, which cannot exercise the overflow bounds those rely on.
    function testFuzz_YulStage2_MatchesSolc(uint256 seed) public {
        uint256 P = 0xFFFFFFFF00000001;
        uint256[12] memory l;
        for (uint256 i = 0; i < 12; i++) {
            l[i] = uint256(keccak256(abi.encode(seed, i))) % P; // canonical field element < p
        }
        // pack 12 lanes -> 3 words (4 lanes/word, low limb first) — the stage's ABI convention
        uint256 w0 = l[0] | (l[1] << 64) | (l[2] << 128) | (l[3] << 192);
        uint256 w1 = l[4] | (l[5] << 64) | (l[6] << 128) | (l[7] << 192);
        uint256 w2 = l[8] | (l[9] << 64) | (l[10] << 128) | (l[11] << 192);
        (uint256 s0, uint256 s1, uint256 s2) = PGStage2.run(w0, w1, w2);
        (uint256 y0, uint256 y1, uint256 y2) = _yulRun(w0, w1, w2);
        assertEq(y0, s0, "fuzz: word0 != solc");
        assertEq(y1, s1, "fuzz: word1 != solc");
        assertEq(y2, s2, "fuzz: word2 != solc");
    }

    /// Deployed Yul stays well under EIP-170 and below the solc stage size (10,658 B).
    function test_YulStage2_Size() public view {
        uint256 sz = yul.code.length;
        console2.log("yul PGStage2 runtime size:", sz);
        assertLt(sz, 24576, "exceeds EIP-170");
        assertLt(sz, 10658, "not smaller than solc PGStage2");
    }

    /// The Yul stage must not be slower than the solc stage (it is ~10% cheaper).
    function test_YulStage2_GasNotWorse() public {
        (uint256 a, uint256 b, uint256 c) = PGStage1.run(0, 0, 0);
        PGStage2.run(a, b, c); // warm
        _yulRun(a, b, c);

        uint256 g1 = gasleft();
        PGStage2.run(a, b, c);
        uint256 gSolc = g1 - gasleft();
        uint256 g2 = gasleft();
        _yulRun(a, b, c);
        uint256 gYul = g2 - gasleft();

        console2.log("solc stage2 gas:", gSolc);
        console2.log("yul  stage2 gas:", gYul);
        assertLe(gYul, gSolc, "yul stage2 slower than solc");
    }

    /// Inverse-drift guard. The suite (and the production deploy) read yul/Stage2.hex, NOT the
    /// yul/Stage2.yul source — so editing the .yul and forgetting to re-run yul/build.sh would leave
    /// everything validating STALE bytecode. This recompiles Stage2.yul (via build.sh, to a temp) and
    /// asserts it matches the committed Stage2.hex byte-for-byte. Needs ffi=true (foundry.toml); skips
    /// cleanly when the pinned solc is absent (set SOLC=) so it never false-fails in a toolchain-less CI.
    function test_Stage2HexMatchesYulSource() public {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "SOLC=\"${SOLC:-$HOME/.local/share/svm/0.8.24/solc-0.8.24}\";"
            " if [ ! -x \"$SOLC\" ]; then printf SKIP; exit 0; fi;"
            " if OUT=/tmp/stage2_driftcheck.hex bash yul/build.sh 2 >/dev/null 2>&1 &&"
            " diff -q /tmp/stage2_driftcheck.hex yul/Stage2.hex >/dev/null 2>&1;"
            " then printf MATCH; else printf STALE; fi";
        bytes memory out = vm.ffi(cmd);
        if (keccak256(out) == keccak256(bytes("SKIP"))) {
            emit log("test_Stage2HexMatchesYulSource SKIPPED: pinned solc not found (set SOLC= to enable)");
            return;
        }
        assertEq(string(out), "MATCH", "yul/Stage2.hex is STALE -- re-run yul/build.sh after editing yul/Stage2.yul");
    }
}
