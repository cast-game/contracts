// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./Tickets.sol";

contract Game is Ownable {
    using ECDSA for bytes32;

    Tickets public tickets;

    address public protocolTreasury = 0x0;
    address public channelHost;

    // 5% protocol fee
    address public protocolFeePercent = 0.05 ether;
    // 5% channel host fee (of final prize pool)
    address public hostFeePercent = 0.05 ether;
    // 15% winning cast creator fee (of final prize pool)
    address public creatorFeePercent = 0.15 ether;

    // Nonce to ensure hashes are unique per transaction
    mapping(string => uint256) public nonce;

    error InsufficientPayment();
    error TransferFailed();

    constructor(address _channelHost, address _tickets) Ownable(msg.sender) {
        tickets = Tickets(_tickets);
        channelHost = _channelHost;
    }

    /// @notice recover the signer from the hash and signature
    function verifySignature(
        bytes memory signature,
        bytes32 hash
    ) internal view {
        address signer = MessageHashUtils.toEthSignedMessageHash(hash).recover(
            signature
        );
        if (signer != owner()) revert InvalidSignature();
    }

    function buyTickets(
        string memory castHash,
        address castCreator,
        uint256 amount,
        uint256 scv,
        bytes memory signature
    ) external payable {
        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                amount,
                scv,
                nonce[castHash]
            )
        );

        verifySignature(signature, hash);
        nonce[castHash]++;

        // TODO: get price from bonding curve + scv
        uint256 price = 1 ether;

        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 creatorFee = (price * creatorFeePercent) / 1 ether;

        if (msg.value < price + protocolFee + creatorFee)
            revert InsufficientPayment();

        // Transfer the fees
        (bool success0, ) = protocolTreasury.call{value: protocolFee}("");
        (bool success1, ) = castCreator.call{value: creatorFee}("");
        if (!success0 || !success1) revert TransferFailed();

        // TODO: mint ERC1155 token from Tickets.sol

        // TODO: emit event
    }
}
