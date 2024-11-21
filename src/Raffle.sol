//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";
// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// view & pure functions

/**
 * @title Raffle
 * @author @jopoepl
 * @notice This contract is for creating a sample raffle using Chainlink VRF and Chainlink Automation
 * @dev Implements Chainlink VRF and Chainlink Automation
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*ERRORS*/
    error Raffle__NotEnoughEthSent();
    error RAFFLE_RAFFLENOTOPEN();
    error RAFFLE_TRANSFERFAILED();
    error RAFFLE__TooEarly(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* TYPE DECLARATIONS */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* STATE VARIABLES */
    uint256 private immutable i_entranceFee;
    //@dev interval between raffle picks in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    bool private immutable i_enableNativePayment;
    uint256 private immutable i_subscriptionId;

    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    // Events

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        bool enableNativePayment
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;

        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_enableNativePayment = enableNativePayment;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    //Functions
    //Enter the raffle
    //Pick a winner
    //Chainlink keepers

    //Getters --> functions that let us view the state of the contract
    //getEntranceFee ✅
    //getRaffleState
    //getPlayer(uint256 index)
    //getLastWinner

    function enterRaffle() external payable {
        //require msg.value is equal to or greater than the entrance fee
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert RAFFLE_RAFFLENOTOPEN();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }
    /**
     * DESCRIPTION OF THE FUNCTION
     * @dev this is the function that the chainlink keeper nodes call
     * they look for the upkeepNeeded to be true
     * the performData is the data that will be passed to the performUpkeep function
     * Upkeep is needed if
     * 1. Raffle is open
     * 2. Time has passed since last raffle pick
     * 3. There are at least 1 player and some ETH has been sent
     * 4. Implicitly your subscription is funded with LINK
     * @return upkeepNeeded boolean value
     * @return ignored performData
     */

    function checkUpkeep(bytes memory /* performData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHaspassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded = (timeHaspassed && hasPlayers && hasBalance && raffleIsOpen);
        return (upkeepNeeded, "0x0"); //0x0 is the performData - which we are not using
    }

    function performUpkeep(bytes memory /* performData */ ) external {
        //require time has passed

        (bool upkeepNeeded,) = checkUpkeep(new bytes(0));
        if (!upkeepNeeded) {
            revert RAFFLE__TooEarly(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        // Define a struct to hold the request details
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: i_enableNativePayment}))
        });
        //pass the request to the VRF coordinator
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);

        //pick a random winner
        //set internal at auto pick winner
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner); //goes here because it's effects | not interactions of CEI
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        console.log("Recent winner:", recentWinner, recentWinner.balance);
        if (!success) {
            revert RAFFLE_TRANSFERFAILED();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
