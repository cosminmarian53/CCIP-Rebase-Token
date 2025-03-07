// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        // Deploy the RebaseToken contract on the sepolia fork.
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        // we want users to only deposit and redeem on the source chain
        vault = new Vault(IRebaseToken(sepoliaToken));
        vm.stopPrank();
        // Deploy the RebaseToken contract on the arbitrum-sepolia fork.
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        vm.stopPrank();
    }
}
