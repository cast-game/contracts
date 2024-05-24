// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Game is Ownable {
    using ECDSA for bytes32;

    address public protocolTreasury = 0x0;
    address public channelHost;

    // 5% protocol fee
    address public protocolFeePercent = 0.05 ether;
    // 5% channel host fee (of final prize pool)
    address public hostFeePercent = 0.05 ether;
    // 15% winning cast creator fee (of final prize pool)
    address public creatorFeePercent = 0.15 ether;

    constructor(address _channelHost) Ownable(msg.sender) {
        channelHost = _channelHost;
    }
}
