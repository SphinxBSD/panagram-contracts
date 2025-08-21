// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVerifier} from "./Verifier.sol";

contract Panagram is ERC1155, Ownable {
    IVerifier public s_verifier;
    bytes32 public s_answer;
    address public s_currentRoundWinner;
    uint256 public s_currentRound;

    uint256 public constant MIN_DURATION = 10800; // 3 hours
    uint256 public s_roundStartTime;
    mapping (address => uint256) public s_lastCorrectGuessRound;

    // Events
    event Panagram__VerifierUpdated(IVerifier _verifier);
    event Panagram__NewRoundStarted(bytes32 _answer);
    event Panagram__WinnerCrowned(address indexed winner, uint256 round);
    event Panagram__RunnerUpCrowned(address indexed runnerUp, uint256 indexed round);

    // Errors
    error Panagram__MinTimeNotPassed(uint256 minDuration, uint256 timePassed);
    error Panagram__NoRoundWinner();
    error Panagram__FirstPanagramNotSet();
    error Panagram__AlreadyGuessedCorrectly(uint256 round, address user);
    error Panagram__InvalidProof();

    constructor(IVerifier _verifier) ERC1155("ipfs://bafybeicqfc4ipkle34tgqv3gh7gccwhmr22qdg7p6k6oxon255mnwb6csi/{id}.json") Ownable(msg.sender){
        s_verifier = _verifier;
    }

    // Function to create a new round
    function newRound(bytes32 _answer) external onlyOwner {
        if(s_roundStartTime == 0) {
            s_roundStartTime = block.timestamp;
            s_answer = _answer;
        } else {
            if (block.timestamp < s_roundStartTime + MIN_DURATION){
                revert Panagram__MinTimeNotPassed(MIN_DURATION, block.timestamp - s_roundStartTime);
            }
            if (s_currentRoundWinner == address(0)) {
                revert Panagram__NoRoundWinner();
            }
            // Reset the round
            s_answer = _answer;
            s_currentRoundWinner = address(0);
        }
        s_currentRound++;
        emit Panagram__NewRoundStarted(_answer);
    }

    // Function to allow users to submit a guess
    function makeGuess(bytes memory proof) external returns (bool) {
        // Check wether the first round has been started
        if (s_currentRound == 0) {
            revert Panagram__FirstPanagramNotSet();
        }
        // Check if the user has already guessed correctly
        if (s_lastCorrectGuessRound[msg.sender]== s_currentRound){
            revert Panagram__AlreadyGuessedCorrectly(s_currentRound, msg.sender);
        }
        // Check the proof and verify it with the Verifier contract
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = s_answer;
        publicInputs[1] = bytes32(uint256(uint160(msg.sender)));
        bool proofResult = s_verifier.verify(proof, publicInputs);
        
        // revert if incorrect
        if (!proofResult){
            revert Panagram__InvalidProof();
        }
        s_lastCorrectGuessRound[msg.sender] = s_currentRound;

        // if correct, check if they are first, if they are then mint NFT ID 0
        if (s_currentRoundWinner == address(0)){
            s_currentRoundWinner = msg.sender;
            _mint(msg.sender, 0, 1, "");
            emit Panagram__WinnerCrowned(msg.sender, s_currentRound);
        } else {
            // If correct and not first, mint NFT ID 1
            _mint(msg.sender, 1, 1, "");
            emit Panagram__RunnerUpCrowned(msg.sender, s_currentRound);
        }
        return proofResult;
    }

    // Set a new verifier
    function setVerifier(IVerifier _verifier) external onlyOwner {
        s_verifier = _verifier;
        emit Panagram__VerifierUpdated(_verifier);
    }
}