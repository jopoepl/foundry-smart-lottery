//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "../src/Raffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        (Raffle raffle, HelperConfig helperConfig) = deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //if on local chain, deploy mocks, get network config
        //if on sepolia, get sepolia network config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfigByChainId(block.chainid);
        if (networkConfig.vrfCoordinator == address(0)) {
            revert("Network config not set for chainId");
        }

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscriptionUsingConfig();


    
    // 4. Updates both mappings in HelperConfig
    helperConfig.updateNetworkConfig(block.chainid, networkConfig);
            

        }
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link, networkConfig.account
        );


        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit,
            networkConfig.enableNativePayment
        );
        vm.stopBroadcast();

        console.log("Raffle networkconfig:", networkConfig.subscriptionId);

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.account);

        return (raffle, helperConfig);
    }
}
