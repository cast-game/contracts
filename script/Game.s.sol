// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/Game.sol";
import "../src/Tickets.sol";

contract GameScript is Script {
    function setUp() public {}

    function run() public {
        // test (dev wallet)
        address channelHost = 0xa85B5383e0E82dBa993747834f91FE03FCCD40ab;
        address protocolTreasury = 0xa85B5383e0E82dBa993747834f91FE03FCCD40ab;

        // dev wallet
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        Tickets tickets = new Tickets();
        Game game = new Game(
            "test",
            channelHost,
            address(tickets),
            protocolTreasury
        );

        tickets.setMinter(address(game));
        // remove in prod
        game.startGame(1748697936, 1748697937);
    }
}
