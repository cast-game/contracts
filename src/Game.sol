// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Tickets.sol";

contract Game is Ownable {
    using ECDSA for bytes32;

    Tickets public tickets;
    IERC20 public token;

    address public protocolTreasury = address(0);
    address public channelHost;

    // 5% protocol fee
    uint256 public protocolFeePercent = 0.05 ether;
    // 5% creator fee (of transaction)
    uint256 public creatorFeePercent = 0.05 ether;
    // 5% channel host fee (of final prize pool)
    uint256 public hostFeePercent = 0.05 ether;
    // 15% winning cast creator fee (of final prize pool)
    uint256 public winnningCreatorFeePercent = 0.15 ether;

    bool public isActive = false;
    uint256 public endBlock;

    // Nonce to ensure hashes are unique per transaction
    mapping(string => uint256) public nonce;

    event Purchase(
        address indexed buyer,
        string indexed castHash,
        uint256 amount,
        uint256 price,
        uint256 protocolFee,
        uint256 creatorFee
    );

    event GameEnded(
        string indexed castHash,
        address indexed winningCreator,
        address[] ticketHolders
    );

    error InsufficientPayment();
    error TransferFailed();
    error GameNotActive();
    error GameStillActive();
    error InvalidSignature();

    constructor(
        address _channelHost,
        address _tickets,
        address _token
    ) Ownable(msg.sender) {
        tickets = Tickets(_tickets);
        token = IERC20(_token);
        channelHost = _channelHost;
    }

    function startGame(uint256 duration) external onlyOwner {
        isActive = true;
        endBlock = block.number + duration;
    }

    function updateGameStatus(bool _isActive) external onlyOwner {
        isActive = _isActive;
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

    function buy(
        string memory castHash,
        address castCreator,
        uint256 amount,
        uint256 price,
        bytes memory signature
    ) external {
        if (!isActive || block.number > endBlock) revert GameNotActive();

        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                amount,
                price,
                nonce[castHash]
            )
        );

        verifySignature(signature, hash);
        nonce[castHash]++;

        // Calculate fees
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 creatorFee = (price * creatorFeePercent) / 1 ether;

        if (token.balanceOf(msg.sender) < price + protocolFee + creatorFee)
            revert InsufficientPayment();

        // Transfer fees
        token.transferFrom(msg.sender, protocolTreasury, protocolFee);
        token.transferFrom(msg.sender, castCreator, creatorFee);

        // Mint ERC1155
        tickets.mint(msg.sender, castHash, amount);

        emit Purchase(
            msg.sender,
            castHash,
            amount,
            price,
            protocolFee,
            creatorFee
        );
    }

    function endGame(
        string memory castHash,
        address winningCreator,
        address[] calldata ticketHolders
    ) external onlyOwner {
        if (block.number < endBlock) revert GameStillActive();

        uint256 prizePool = token.balanceOf(address(this));

        // Calculate fees
        uint256 hostFee = (prizePool * hostFeePercent) / 1 ether;
        uint256 winningCreatorFee = (prizePool * winnningCreatorFeePercent) /
            1 ether;

        // Transfer fees
        token.transferFrom(address(this), channelHost, hostFee);
        token.transferFrom(address(this), winningCreator, winningCreatorFee);

        // Distribute the rest of the prize pool to ticket holders
        uint256 remainingPool = token.balanceOf(address(this));
        
        for (uint256 i = 0; i < ticketHolders.length; i++) {
            token.transferFrom(
                address(this),
                ticketHolders[i],
                remainingPool / ticketHolders.length
            );
        }

        emit GameEnded(castHash, winningCreator, ticketHolders);
    }
}
