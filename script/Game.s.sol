// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/Game.sol";
import "../src/Tickets.sol";

contract GameScript is Script {
    function setUp() public {}

    function run() public {
        // testnet demo
        address channelHost = 0xF5745cD4d5BC2E3B7352676544Ea632A9a30FecD;
        address protocolTreasury = 0xffCCfe5E0B1332A4A83694785f6b8867d6c85DfA;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        // Tickets tickets = new Tickets();
        Game game = new Game(
            // "test",
            channelHost,
            // address(tickets),
            protocolTreasury
        );

        // tickets.setMinter(address(game));
        // remove in prod
        game.startGame(block.number + 999999, block.number + 1000000);
    }
}
