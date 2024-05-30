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

    address public protocolTreasury;
    address public channelHost;

    uint256 constant TICKETS_MAX_SUPPLY = 100;

    /// @notice transaction fees
    uint256 public feePercent = 0.05 ether;
    uint256 public referralFeePercent = 0.1 ether;

    // of final prize pool
    uint256 public winnningCreatorFeePercent = 0.15 ether;

    bool public isPaused = false;
    uint256 public tradingEndBlock;
    uint256 public endBlock;

    // Nonce to ensure hashes are unique per transaction
    mapping(string => uint256) public nonce;

    event Purchased(
        address indexed buyer,
        string indexed castHash,
        address indexed castCreator,
        address referrer,
        uint256 amount,
        uint256 price
    );

    event Sold(
        address indexed seller,
        string indexed castHash,
        address indexed castCreator,
        uint256 amount,
        uint256 price
    );

    event GameEnded(
        string indexed castHash,
        address indexed winningCreator,
        address[] ticketHolders
    );

    error InsufficientPayment();
    error TransferFailed();
    error GameNotActive();
    error GameNotOver();
    error InvalidSignature();
    error MaxSupply();

    constructor(
        address _channelHost,
        address _ticketsAddress,
        address _token,
        address _treasury
    ) Ownable(msg.sender) {
        tickets = Tickets(_ticketsAddress);
        token = IERC20(_token);
        channelHost = _channelHost;
        protocolTreasury = _treasury;
    }

    // Admin functions
    function startGame(
        uint256 _tradingEndBlock,
        uint256 _endBlock
    ) external onlyOwner {
        isPaused = false;
        tradingEndBlock = _tradingEndBlock;
        endBlock = _endBlock;
    }

    function updateGameStatus(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }

    function updateChannelHost(address _channelHost) external onlyOwner {
        channelHost = _channelHost;
    }

    function updateProtocolTreasury(
        address _protocolTreasury
    ) external onlyOwner {
        protocolTreasury = _protocolTreasury;
    }

    function payout(
        address[] calldata winners,
        uint256[] calldata amounts
    ) external onlyOwner {
        if (block.number < endBlock) revert GameNotOver();

        for (uint256 i = 0; i < winners.length; i++) {
            token.transfer(winners[i], amounts[i]);
        }
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
        address referrer,
        bytes memory signature
    ) external {
        if (isPaused || block.number > tradingEndBlock) revert GameNotActive();

        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                amount,
                price,
                referrer,
                nonce[castHash]
            )
        );

        verifySignature(signature, hash);
        nonce[castHash]++;

        uint256 feeAmount = (price * feePercent) / 1 ether;

        // Transfer fees
        token.transferFrom(msg.sender, protocolTreasury, feeAmount);
        token.transferFrom(msg.sender, castCreator, feeAmount);
        token.transferFrom(msg.sender, channelHost, feeAmount);

        // Optionally transfer referral fee
        uint256 amountAfterFees = price - (feeAmount * 3);
        if (referrer != address(0)) {
            uint256 referralFee = (price * referralFeePercent) / 1 ether;
            token.transferFrom(msg.sender, referrer, referralFee);
            amountAfterFees -= referralFee;
        }

        // Transfer payment
        token.transferFrom(msg.sender, address(this), amountAfterFees);

        // Mint ERC1155
        tickets.mint(msg.sender, castHash, amount);

        emit Purchased(
            msg.sender,
            castHash,
            castCreator,
            referrer,
            amount,
            price
        );
    }

    function sell(
        string memory castHash,
        address castCreator,
        uint256 amount,
        uint256 price,
        address referrer,
        bytes memory signature
    ) external {
        if (isPaused || block.number > tradingEndBlock) revert GameNotActive();

        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                amount,
                price,
                referrer,
                nonce[castHash]
            )
        );

        verifySignature(signature, hash);
        nonce[castHash]++;

        // Calculate fees
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 creatorFee = (price * creatorFeePercent) / 1 ether;

        // Transfer fees
        token.transfer(protocolTreasury, protocolFee);
        token.transfer(castCreator, creatorFee);

        // Optionally transfer referral fee
        uint256 finalSellAmount = price - protocolFee - creatorFee;
        if (referrer != address(0)) {
            uint256 referralFee = (price * referralFeePercent) / 1 ether;
            token.transfer(referrer, referralFee);
            finalSellAmount -= referralFee;
        }

        // Transfer payment
        token.transfer(msg.sender, finalSellAmount);

        // Burn ERC1155
        tickets.burn(msg.sender, castHash, amount);

        emit Sold(msg.sender, castHash, amount, price, protocolFee, creatorFee);
    }
}
