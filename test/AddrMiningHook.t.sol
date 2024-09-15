// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

// import "forge-std/console.sol";
// import {Vm} from "forge-std/Vm.sol";
// import "forge-std/Vm.sol";

// import {Test, console, Vm} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import {AddressMiningHook} from "../src/AddrMiningHook.sol";
import {Utils} from "../src/Utils.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

contract AddressMiningHookTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;

    AddressMiningHook public hook;

    PoolKey pool_key;
    PoolId pool_id;

    // the first index got an address with 0 prefix.
    uint8 success_index = 0;

    function setUp() public {
        // Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        (token0, token1) = deployMintAndApprove2Currencies();

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags);
        // Deploy our hook
        deployCodeTo("AddrMiningHook.sol", abi.encode(manager, "Addr Owner NFT", "ADOWN"), hookAddress);
        hook = AddressMiningHook(hookAddress);

        // Approve our hook address to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(hook), type(uint256).max);

        // Initialize a pool
        (pool_key, pool_id) = initPool(
            token0, // Currency 0 = ETH
            token1, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1, // Initial Sqrt(P) value = 1
            ZERO_BYTES // No additional `initData`
        );

        // Add some liquidity from -60 to +60 tick range
        modifyLiquidityRouter.modifyLiquidity(
            pool_key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        for (uint8 i = 0; i < 1000; i++) {
            (address addr,) = hook.getCreate2Address(i);
            if (Utils.hasZeroPrefix(addr, 1)) {
                success_index = i;
                break;
            }
        }
        assertGt(success_index, 0); // Ensure we find a match address
    }

    // A helper to make swap transaction
    function do_swap(bool zeroForOne, int128 amountSpecified, bytes memory hookdata) public {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne, //true: from token 0 to token 1
            amountSpecified: amountSpecified * -1,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        // After swap transaction, our hook will be triggered
        swapRouter.swap(pool_key, params, testSettings, hookdata);
    }

    // Test initialize the test, make sure everything works normally.
    function test_setup() public view {
        console.log(hook.miningCount());
        assertEq(hook.miningCount(), 0);
    }

    // Test generate proxy address with create2 function.
    // ensure hasZeroPrefix and getCreate2Address works
    // Address is calculated by hook address(which is deployer of proxy contract), and proxy contract bytecode
    // there will be a nonce too, we use block.prevrandao and calculation secquence number as a random source.
    // If this hook go online, we should design a more complex random source.
    function test_generateAddress() public view {
        for (uint8 i = 0; i < 50; i++) {
            (address addr,) = hook.getCreate2Address(i);
            console.log(addr);
            if (Utils.hasZeroPrefix(addr, 1)) {
                console.log(i);
            }
        }
    }

    //just swap, do not mining address.
    function test_swapNoMining1() public {
        assertEq(hook.miningCount(), 0);
        do_swap(true, -0.1 ether, "");
        //miningCount will not change
        assertEq(hook.miningCount(), 0);
    }
    //test swap, but don't mining address by setting mining count to 0

    function test_swapNoMining2() public {
        assertEq(hook.miningCount(), 0);
        do_swap(true, -0.1 ether, hook.getHookData(0, 0));
        //miningCount will not change
        assertEq(hook.miningCount(), 0);
    }

    //mining, but did not get an address
    function test_swapMiningFailed() public {
        assertEq(hook.miningCount(), 0);

        uint256 nftId = hook.nextNftId();
        vm.recordLogs();
        do_swap(true, -0.1 ether, hook.getHookData(success_index - 1, 1));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        /*
        Got 3 logs
        1. swap
        4. transfer token of swap
        5. transfer token of swap
         */
        printLogs(logs);
        //nftId will not change
        assertEq(nftId, hook.nextNftId());
        //mining count add 1
        assertEq(hook.miningCount(), 1);
    }

    //mining, and successed to get a address
    //If a address is mined, a nft will be minted to user. This nft can be transfered
    //Any one with this nft can claim the address.
    function test_swapMiningSuccess() public {
        assertEq(hook.miningCount(), 0);

        uint256 nftId = hook.nextNftId();
        vm.recordLogs();
        do_swap(true, -0.1 ether, hook.getHookData(success_index + 1, 1));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        /*
        Got 5 logs
        1. swap
        2. mint nft in hook
        3. GotAddress in hook
        4. transfer token of swap
        5. transfer token of swap
         */
        printLogs(logs);
        ensure_has_topic(logs, 0x0a95cf3ad7c952c12ca1ceb27c6ee3cfd89ac6a3b333cd4f5d9f62154541d7c1); //GotAddress

        // ensure owner of nft is user
        address user = address(uint160(uint256(logs[2].topics[1])));

        assertEq(hook.ownerOf(nftId), user);
        // id of nft add 1
        assertEq(nftId + 1, hook.nextNftId());
        // mining count add 1
        assertEq(hook.miningCount(), 1);
    }

    //A helper function to print event logs
    function printLogs(Vm.Log[] memory logs) public pure {
        console.log("============show logs===============");

        for (uint256 i = 0; i < logs.length; i++) {
            console.log(i);
            for (uint256 j = 0; j < logs[i].topics.length; j++) {
                console.logBytes32(logs[i].topics[j]);
            }
            console.logBytes(logs[i].data);
        }
    }

    function ensure_has_topic(Vm.Log[] memory logs, bytes32 topic) public pure {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic) {
                return;
            }
        }
        assert(false);
    }

    //Test claim
    //User with the NFT can claim the address
    //1. nft will be burned, and the ownership will be verified.
    //2. a proxy contract will be deployed to the 0 prefix address
    //3. the owner of the contract will be set to user.
    //4. user can set implementation, so he can call another contract with this address
    function test_claim() public {
        //mining
        uint256 nftId = hook.nextNftId();
        vm.recordLogs();
        do_swap(true, -0.1 ether, hook.getHookData(success_index + 1, 1));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        printLogs(logs);

        address user = address(uint160(uint256(logs[2].topics[1])));
        assertEq(hook.ownerOf(nftId), user);
        //claim
        vm.recordLogs();
        hook.claim(nftId);
        logs = vm.getRecordedLogs();
        /**
         * Got 3 logs
         *     1. burn nft in hook
         *     2. transfer proxy owner
         *     3. ClaimAddress in hook
         */
        ensure_has_topic(logs, 0x6a6da33b6dde744f508c9d46debf525683fbcc9da86cb96c9ba3ee890dc03589); //claim
        printLogs(logs);
    }

    //Test claim again, but the nft has burned, so claim will be failed.
    function test_claim_again() public {
        //mining
        uint256 nftId = hook.nextNftId();
        do_swap(true, -0.1 ether, hook.getHookData(success_index + 1, 1));
        //claim
        hook.claim(nftId);
        vm.expectRevert("NOT_MINTED");
        hook.claim(nftId);
    }
}
