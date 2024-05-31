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
        // test degen (mockerc20)
        address tokenAddress = 0x6E67E6AE4A1fB0b8c45897ECCfdCE8408B1e1640;

        // dev wallet
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        Tickets tickets = new Tickets();
        Game game = new Game(
            "test",
            channelHost,
            address(tickets),
            tokenAddress,
            protocolTreasury
        );

        tickets.setMinter(address(game));
        // remove in prod
        game.startGame(1748697936, 1748697937);
    }
}
