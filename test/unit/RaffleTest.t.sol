//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {codeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, codeConstants {


    //Modifiers


    modifier RafflePlayerEntered() {
        hoax(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    // Events

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;
    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    bytes32 public gasLane;
    uint256 public subscriptionId;
    uint32 public callbackGasLimit;
    bool public enableNativePayment;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;
        enableNativePayment = networkConfig.enableNativePayment;

       


            console.log("Mock setup complete");
            console.log("VRF Coordinator:", address(vrfCoordinator));
            console.log("Raffle:", address(raffle));
            console.log("SubscriptionId:", subscriptionId);
        
    }

    function testRaffleInitializedAndStateIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleUserHasRevertsWithLessThanMinimumEntranceFee() public {
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testRaffleRecordsPlayersWhenEntered() public {
        hoax(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers().length == 1);
        assert(raffle.getPlayers()[0] == PLAYER);
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testRaffleEmitsEventOnEntrance() public {
        hoax(PLAYER, STARTING_PLAYER_BALANCE);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsClosed() public {
        hoax(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.RAFFLE_RAFFLENOTOPEN.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPerformUpkeepShouldOnlyRunIfCheckUpkeepIsTrue() public RafflePlayerEntered {
        hoax(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    modifier skipForkTest() {
        if(block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    /**
     * FULFILL RANDOM WORDS TESTING
     */
    function testFulfillRandomWordsOnlyRunsIfPerformUpkeepIsTrue(uint256 randomRequestId) public skipForkTest {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    //RANDOM WORDS FINAL BIG TEST

    function testRandomWordsPicksRandomWinnerAndSendsMoney() public RafflePlayerEntered skipForkTest {
        uint256 startingPlayerIndex = 1;
        uint256 newPlayers = 3;
        address expectedWinner = address(1);

        // Add debugging to verify initial conditions
        console.log("Initial balance:", address(raffle).balance);
        console.log("Players length:", raffle.getPlayers().length);
        console.log("Last timestamp:", raffle.getLastTimeStamp());
        console.log("Current timestamp:", block.timestamp);
        console.log("Raffle state:", uint256(raffle.getRaffleState()));

        for (uint256 i = startingPlayerIndex; i < startingPlayerIndex + newPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        console.log("Final balance:", address(raffle).balance);
        console.log("Final players length:", raffle.getPlayers().length);

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        //ACT
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

      bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //ASSERT
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 prize = entranceFee * (newPlayers + 1);


        console.log("Expected winner:", expectedWinner);
    console.log("Actual winner:", recentWinner);
    console.log("Winner final balance:", recentWinner.balance);
        console.log("Prize:", prize);

    console.log("Expected final balance:", STARTING_PLAYER_BALANCE - entranceFee + prize);
        assert(winnerBalance == STARTING_PLAYER_BALANCE - entranceFee + prize); //since winner's balance is less than starting player balance because of the entrance fee
        assert(uint256(raffleState) == 0);
        assert(block.timestamp - startingTimeStamp >= interval);
        assert(recentWinner == expectedWinner);
    }
}
