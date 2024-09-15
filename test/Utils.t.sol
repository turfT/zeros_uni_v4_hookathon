// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {Test, console} from "forge-std/Test.sol";
import {Utils} from "../src/Utils.sol";

contract AddressMiningHookTest is Test {
    function setUp() public {}

    function test_checkAddr() public pure {
        bool result = Utils.hasZeroPrefix(address(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC), 14); //
        assertEq(result, true);
        result = Utils.hasZeroPrefix(address(0x00000000219ab540356cBB839Cbe05303d7705Fa), 8); //
        assertEq(result, true);
    }

    function test_randomNonce() public {
        // vm.difficulty(25);
        vm.prevrandao(bytes32(uint256(42)));
        vm.warp(1512918335);
        uint256 length = 10000000000;
        uint160 sqrtPriceLimitX96 = 100;
        uint256 nonce = Utils.randNonce(msg.sender, length, sqrtPriceLimitX96);
        console.log("nonce: %s", nonce);
        assertEq(nonce, 9808036631);
    }
}
