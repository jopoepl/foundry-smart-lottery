//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {codeConstants} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
                address account = helperConfig.getConfig().account;

        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        console.log("Subscription ID: ", subId);
        console.log("Please update sub id in your s_networkconfig");
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        return (subId, vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, codeConstants {
    // Fund the subscription with LINK to use VRF

    uint256 public constant FUND_AMOUNT = 3 ether; // LINK ~ ETHER ~ 1e18

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subId, link, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address link, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using VrfCoordinator: ", vrfCoordinator);
        console.log("On Chain: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);

            LinkToken linkToken = LinkToken(link);
            linkToken.transferAndCall(address(vrfCoordinator), FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script, codeConstants {
    function addConsumerUsingConfig(address raffleContract) public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        addConsumer(raffleContract, vrfCoordinator, subId, account);
    }

    function addConsumer(address raffleContract, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract:", raffleContract);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On chainid:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, raffleContract);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffleContract);
    }
}
