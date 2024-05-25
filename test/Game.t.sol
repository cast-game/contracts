// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";

import "../src/Game.sol";
import "../src/Tickets.sol";
import "../src/MockERC20.sol";

contract CounterTest is Test {
    address public protocolTreasury = address(2);
    address public channelHost = address(1);

    ERC20 public token;
    Game public game;
    Tickets public tickets;

    function setUp() public {
        token = new MockERC20();
        tickets = new Tickets();

        game = new Game(channelHost, address(tickets), address(token));
    }
}
