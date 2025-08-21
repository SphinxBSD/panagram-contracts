// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { Panagram } from "../src/Panagram.sol";
import { HonkVerifier} from "../src/Verifier.sol";

contract PanagramTest is Test {
    HonkVerifier public verifier;
    Panagram public panagram;
    address user = makeAddr("user");
    uint256 constant FIELD_MODULUS = 
    21888242871839275222246405745257275088548364400416034343698204186575808495617;
    bytes32 constant ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("triangles")) % FIELD_MODULUS)))) % FIELD_MODULUS);
    bytes32 constant CORRECT_GUESS = bytes32(uint256(keccak256("triangles")) % FIELD_MODULUS);
    bytes proof;
    // make a guess
    function setUp() public {
        // deploy the verifier
        verifier = new HonkVerifier();
        // deploy the panagram contract
        panagram = new Panagram(verifier);
        // start the round
        panagram.newRound(ANSWER);
    }

    function _getProof(
        bytes32 guess,
        bytes32 correctAnswer,
        address sender
    ) internal returns(bytes memory _proof) {
        uint256 NUM_ARGS = 6;
        string[] memory inputs = new string[](NUM_ARGS);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateProof.ts";
        inputs[3] = vm.toString(guess);
        inputs[4] = vm.toString(correctAnswer);
        inputs[5] = vm.toString(sender);

        bytes memory encodedProof = vm.ffi(inputs);
        _proof = abi.decode(encodedProof, (bytes));
        // console.logBytes(_proof);
        // bytes memory result = vm.ffi(inputs);
    }

    // 1. Test someone recieves NFT 0 if they guessed correctly first
    function testCorrectGuessPasses() public {
        proof = _getProof(CORRECT_GUESS, ANSWER, user);
        vm.prank(user);
        panagram.makeGuess(proof);
        vm.assertEq(panagram.balanceOf(user, 0), 1);
        vm.assertEq(panagram.balanceOf(user, 1), 0);

        vm.prank(user);
        vm.expectRevert();
        panagram.makeGuess(proof);
    }

    // 2. Test someone recieves NFT 1 if they guessed correctly second
    function testSecondGuessPasses() public {
        
        proof = _getProof(CORRECT_GUESS, ANSWER, user);
        vm.prank(user);
        panagram.makeGuess(proof);
        vm.assertEq(panagram.balanceOf(user, 0), 1);
        vm.assertEq(panagram.balanceOf(user, 1), 0);
        
        address user2 = makeAddr("user2");
        bytes memory proof2 = _getProof(CORRECT_GUESS, ANSWER, user2);
        vm.prank(user2);
        panagram.makeGuess(proof2);
        vm.assertEq(panagram.balanceOf(user2, 0), 0);
        vm.assertEq(panagram.balanceOf(user2, 1), 1);
    }


    // 3. Test we can start a new round
    function testStartSecondRound() public {
        proof = _getProof(CORRECT_GUESS, ANSWER, user);
        vm.prank(user);
        panagram.makeGuess(proof);

        vm.warp(panagram.MIN_DURATION() + 1);
        bytes32 NEW_ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("outnumber")) % FIELD_MODULUS)))) % FIELD_MODULUS);
        panagram.newRound(NEW_ANSWER);

        vm.assertEq(panagram.s_currentRound(), 2);
        vm.assertEq(panagram.s_currentRoundWinner(), address(0));
        vm.assertEq(panagram.s_answer(), NEW_ANSWER);
    }
 
    function testIncorrectGuessFail() public {
        bytes32 INCORRECT_ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("outnumber")) % FIELD_MODULUS)))) % FIELD_MODULUS);
        bytes32 INCORRECT_GUESS = bytes32(uint256(keccak256("outnumber")) % FIELD_MODULUS);

        bytes memory incorrectProof = _getProof(INCORRECT_GUESS, INCORRECT_ANSWER, user);
        vm.prank(user);
        vm.expectRevert();
        panagram.makeGuess(incorrectProof);
    }
}