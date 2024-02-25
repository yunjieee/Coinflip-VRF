//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFv2DirectFundingConsumer} from "./VRFv2DirectFundingConsumer.sol";

contract Coinflip is Ownable, VRFConsumerBaseV2 {
    LinkTokenInterface private linkToken;
    bytes32 private keyHash;
    uint256 private fee;
    // A map of the player and their corresponding random number request
    mapping(address => uint256) public playerRequestID;
    // A map that stores the users coinflip guess
    mapping(address => uint8) public bets;
    mapping(uint256 => bool) public requestFulfilled;
    mapping(uint256 => uint256) public requestResult;
    // An instance of the random number resquestor, client interface
   

    ///@dev we no longer use the seed, instead each coinflip should spawn its own VRF instance
    ///@notice This programming pattern is a factory model - a contract creating other contracts 
    constructor(
        address _vrfCoordinator, // VRF Coordinator address
        address _linkToken, // LINK token address
        bytes32 _keyHash, // Key hash
        uint256 _fee // VRF fee
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        linkToken = LinkTokenInterface(_linkToken);
        keyHash = _keyHash;
        fee = _fee;// Additional setup or state initializations if needed
    }

    // Additional functions (e.g., userInput, fundOracle, checkStatus, fulfillRandomWords) go here


    ///@notice Fund the VRF instance with **2** LINK tokens.
    ///@return A boolean of whether funding the VRF instance with link tokens was successful or not
    ///@dev use the address of LINK token contract provided. Do not change the address!
    ///@custom:attention In order for this contract to fund another contract, which tokens does it require to have before calling this function?
    ///What **additional** functions does this contract need to receive these tokens itself?
    
    function fundOracle() external onlyOwner returns(bool) {
    uint256 amount = 2 * 10**18; // Assuming LINK has 18 decimals
    return linkToken.transfer(address(this), amount);
    }

    ///@notice user guess only ONE flip either a 1 or a 0.
    ///@param guess uint8 which is required to be 1 or 0
    ///@dev After validating the user input, store the user input in global mapping and fire off a request to the VRF instance
    ///@dev Then, store the requestid in global mapping

    
    function userInput(uint8 guess) external {
    require(guess == 0 || guess == 1, "Guess must be 0 or 1");
    require(linkToken.balanceOf(address(this)) >= fee, "Not enough LINK");
    uint256 requestId = requestRandomness(keyHash, fee);
    bets[msg.sender] = guess;
    playerRequestID[msg.sender] = requestId;
}

  

    ///@notice due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow
    ///users to check the status of their request.
    ///@return a boolean of whether the request has been fulfilled or not
    //mapping(uint256 => bool) public requestFulfilled; // Mapping to track if a request has been fulfilled
    //mapping(uint256 => uint256) public requestResult; // Mapping to store the result of each request

    function checkStatus(uint256 requestId) external view returns(bool) {
    return requestFulfilled[requestId];
    }


    ///@notice once the request is fulfilled, return the random result and check if user won
    ///@return a boolean of whether the user won or not based on their input
    ///@dev request the randomWord that is returned. Here you need to check the VRFcontract to understand what type the random word is returned in
    ///@dev simply take the first result, or you can configure the VRF to only return 1 number, and check if it is even or odd. 
    ///     if it is even, the randomly generated flip is 0 and if it is odd, the random flip is 1
    ///@dev compare the user guess with the generated flip and return if these two inputs match.
    
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    requestFulfilled[requestId] = true;
    requestResult[requestId] = randomWords[0];
    }

    
    function determineFlip(uint256 requestId) external view returns(bool) {
    require(requestId != 0, "No request made");
    require(requestFulfilled[requestId], "Request not fulfilled yet");
    uint256 result = requestResult[requestId];
    bool flipResult = result % 2 == 0; // 0 for even, 1 for odd
    return flipResult == (bets[msg.sender] == 1);
    }

}