// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";

import "../src/Game.sol";
import "../src/Tickets.sol";

contract TicketsTest is Test {
    Tickets public tickets;

    function setUp() public {
        tickets = new Tickets();
        tickets.setMinter(address(this));
    }

    function test_Mint() public {
        tickets.mint(address(1), "0x1", 1);
        assertEq(tickets.balanceOf(address(1), 1), 1);
        assertEq(tickets.castTokenId("0x1"), 1);
        assertEq(tickets.supply(1), 1);
    }

    function testFuzz_Mint(uint256 x) public {
        tickets.mint(address(1), "0x1", x);
        assertEq(tickets.balanceOf(address(1), 1), x);
        assertEq(tickets.supply(1), x);
    }

    function test_SetTokenURI() public {
        tickets.setTokenUri(1, "https://google.com");
        assertEq(tickets.uri(1), "https://google.com");
    }
}
