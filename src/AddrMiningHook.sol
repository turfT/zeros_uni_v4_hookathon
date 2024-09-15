// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {ERC721} from "solmate/src/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/console.sol";
import {Utils} from "./Utils.sol";
import {Proxy} from "./Proxy.sol";

contract AddressMiningHook is BaseHook, ERC721 {
    event GotAddress(address indexed _owner, uint256 indexed _id, address indexed _value);
    event ClaimAddress(address indexed _owner, uint256 indexed _id, address indexed _value);

    uint256 public miningCount;
    uint256 public nextNftId;
    mapping(uint256 => bytes) public nftAddress;

    constructor(IPoolManager _manager, string memory _name, string memory _symbol)
        BaseHook(_manager)
        ERC721(_name, _symbol)
    {
        miningCount = 0;
        nextNftId = 100;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external override onlyByPoolManager returns (bytes4, int128) {
        if (hookData.length == 0) {
            return (this.afterSwap.selector, 0);
        }
        (uint8 calcCount, uint8 zeroCount) = abi.decode(hookData, (uint8, uint8));
        if (calcCount < 1) {
            return (this.afterSwap.selector, 0);
        }
        miningAddress(calcCount, zeroCount);
        miningCount++;
        return (this.afterSwap.selector, 0);
    }

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return string.concat("some_uri_", Strings.toString(id));
    }

    function getHookData(uint8 calcCount, uint8 zeroCount) public pure returns (bytes memory) {
        return abi.encode(calcCount, zeroCount);
    }

    function miningAddress(uint8 calcCount, uint8 zeroCount) private {
        for (uint8 i = 0; i < calcCount; i++) {
            (address genAddr, bytes32 nonce) = getCreate2Address(i);

            if (Utils.hasZeroPrefix(genAddr, zeroCount)) {
                _mint(tx.origin, nextNftId);
                nftAddress[nextNftId] = abi.encode(genAddr, nonce);
                emit GotAddress(tx.origin, nextNftId, genAddr);
                nextNftId += 1;

                break;
            }
        }
    }

    function geneProxy(address owner, bytes32 salt) internal returns (address) {
        // create2 deploy contract
        Proxy proxy = new Proxy{salt: salt}();
        proxy.changeOwner(owner);
        return address(proxy);
    }

    function getCreate2Address(uint8 seed) public view returns (address predictedAddress, bytes32 nonce) {
        // in test environment, block.prevrandao is not random
        nonce = keccak256(abi.encodePacked(seed, block.prevrandao));
        predictedAddress = address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(this), nonce, keccak256(type(Proxy).creationCode)))
                )
            )
        );
    }

    function claim(uint256 id) public {
        _burn(id);
        (address genAddr, bytes32 nonce) = abi.decode(nftAddress[id], (address, bytes32));
        address deployAddr = geneProxy(tx.origin, nonce);
        require(deployAddr == genAddr);
        emit ClaimAddress(tx.origin, id, genAddr);
    }
}
