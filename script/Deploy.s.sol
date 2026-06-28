// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chaintope Inc.
// Author: Yukishige Nakajo <nakajo@chaintope.com>
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PoseidonGoldilocks} from "../src/PoseidonGoldilocks.sol";

/// @title Production deploy: the hand-written Yul stages + the PoseidonGoldilocks contract.
/// @notice Reads the committed creation bytecode (yul/Stage1.hex, yul/Stage2.hex) at runtime — the
///         exact bytecode the differential tests validate — deploys both stages, then deploys
///         PoseidonGoldilocks wired to their addresses.
///
///   forge script script/Deploy.s.sol:Deploy --rpc-url <RPC> --broadcast
///
/// Requires fs read permission for both .hex files (already granted in foundry.toml).
contract Deploy is Script {
    function run() external returns (PoseidonGoldilocks pos, address stage1, address stage2) {
        bytes memory code1 = vm.parseBytes(_trim(vm.readFile("yul/Stage1.hex")));
        bytes memory code2 = vm.parseBytes(_trim(vm.readFile("yul/Stage2.hex")));

        vm.startBroadcast();
        stage1 = _deploy(code1);
        stage2 = _deploy(code2);
        pos = new PoseidonGoldilocks(stage1, stage2);
        vm.stopBroadcast();

        console2.log("Stage1            :", stage1);
        console2.log("Stage2            :", stage2);
        console2.log("PoseidonGoldilocks:", address(pos));
    }

    function _deploy(bytes memory code) internal returns (address a) {
        assembly {
            a := create(0, add(code, 0x20), mload(code))
        }
        require(a != address(0), "stage deploy failed");
    }

    /// Strip trailing ASCII whitespace so vm.parseBytes sees a clean `0x...` string.
    function _trim(string memory s) internal pure returns (string memory) {
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
