// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "../src/Game.sol";
import "../src/Tickets.sol";
import "../src/MockERC20.sol";

contract GameTest is Test {
    using ECDSA for bytes32;

    uint256 ownerPk = vm.envUint("PRIVATE_KEY_DEV");

    address owner = vm.addr(ownerPk);
    address public protocolTreasury = address(1);
    address public channelHost = address(2);

    address public alice = address(3);
    address public bob = address(4);

    MockERC20 public token;
    Game public game;
    Tickets public tickets;

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20();
        tickets = new Tickets();

        game = new Game(
            channelHost,
            address(tickets),
            address(token),
            protocolTreasury
        );
        game.startGame(1000);

        tickets.setGameContract(address(game));
    }

    function generateSignature(
        string memory castHash,
        address castCreator,
        uint256 price,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(castHash, castCreator, price, nonce)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPk,
            MessageHashUtils.toEthSignedMessageHash(hash)
        );
        return abi.encodePacked(r, s, v);
    }

    function test_UpdateGameStatus() public {
        game.updateGameStatus(false);
        assertEq(game.isActive(), false);

        game.updateGameStatus(true);
        assertEq(game.isActive(), true);
    }

    function test_VerifySignature() public {
        vm.startPrank(owner);
        bytes32 hash = keccak256(
            abi.encodePacked(
                "0x1",
                address(alice),
                uint256(1 ether),
                uint256(0)
            ) // nonce starts at 0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPk,
            MessageHashUtils.toEthSignedMessageHash(hash)
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        address signer = MessageHashUtils.toEthSignedMessageHash(hash).recover(
            signature
        );
        assertEq(signer, owner);
    }

    function test_Buy() public {
        vm.startPrank(alice);
        token.mint(1.1 ether);

        // TODO: determine price
        uint256 price = 1 ether;
        token.approve(address(game), price);

        bytes memory signature = generateSignature("0x1", bob, price, 0);
        game.buy("0x1", bob, price, signature);

        assertEq(tickets.balanceOf(alice, 0), 1);
        assertEq(tickets.supply(0), 1);
    }

    function test_Sell() public {
        vm.startPrank(alice);
        token.mint(3 ether);

        // Buying a ticket
        uint256 price = 2 ether;
        token.approve(address(game), price);

        bytes memory signature = generateSignature("0x1", bob, price, 0);
        game.buy("0x1", bob, price, signature);

        // Selling a ticket
        uint256 sellPrice = 1 ether;
        signature = generateSignature("0x1", bob, sellPrice, 1);
        game.sell("0x1", bob, sellPrice, signature);

        assertEq(tickets.balanceOf(alice, 0), 0);
        assertEq(tickets.supply(0), 0);

        uint256 accumulatedFees = ((price + sellPrice) *
            game.creatorFeePercent()) / 1 ether;
        assertEq(token.balanceOf(bob), accumulatedFees);
    }
}
