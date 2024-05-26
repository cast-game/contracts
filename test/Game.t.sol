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

    ERC20 public token;
    Game public game;
    Tickets public tickets;

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20();
        tickets = new Tickets();

        game = new Game(channelHost, address(tickets), address(token));
        game.startGame(1000);

        tickets.setGameContract(address(game));
    }

    function generateSignature(
        string memory castHash,
        address castCreator,
        uint256 price,
        uint256 amount,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(castHash, castCreator, price, amount, nonce)
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
            abi.encodePacked("0x1", address(alice), uint256(1 ether), uint256(0)) // nonce starts at 0
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

    function test_BuyTicket() public {
        // TODO: determine price
        uint256 price = 1 ether;

        
    }

    // TODO: test bonding curve
}
