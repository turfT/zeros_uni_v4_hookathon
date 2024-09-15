// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";

library Utils {
    function hasZeroPrefix(address addr, uint256 zeroCount) public pure returns (bool) {
        uint160 addrValue = uint160(addr);
        return (addrValue >> (160 - zeroCount * 4)) == 0;
    }

    function randNonce(address sender, uint256 length, uint160 sqrtPriceLimitX96) public view returns (uint256 nonce) {
        nonce = uint256(
            keccak256(
                abi.encodePacked(
                    sender,
                    block.prevrandao, // block.difficulty,
                    block.timestamp,
                    sqrtPriceLimitX96
                )
            )
        );
        nonce = nonce % length;
    }
}
