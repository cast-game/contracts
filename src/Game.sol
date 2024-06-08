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
    string public channelId;

    uint256 constant TICKETS_MAX_SUPPLY = 100;

    /// @notice transaction fees
    uint256 public feePercent = 0.05 ether;
    uint256 public referralFeePercent = 0.1 ether;
    uint256 public creatorFeePercent = 0.1 ether;

    bool public isPaused;
    uint256 public tradingEndTime;
    uint256 public endTime;

    // Nonce to ensure hashes are unique per transaction
    mapping(string => uint256) public nonce;

    event Purchased(
        address indexed buyer,
        address indexed castCreator,
        string castHash,
        address referrer,
        uint256 amount,
        uint256 price
    );

    event Sold(
        address indexed seller,
        address indexed castCreator,
        string castHash,
        address referrer,
        uint256 amount,
        uint256 price
    );

    event GameStarted(uint256 tradingEndTime, uint256 endTime);

    error InsufficientPayment();
    error TransferFailed();
    error GameNotActive();
    error GameNotOver();
    error InvalidSignature();
    error MaxSupply();
    error InvalidParams();

    constructor(
        string memory _channelId,
        address _channelHost,
        address _ticketsAddress,
        address _token,
        address _treasury
    ) Ownable(msg.sender) {
        tickets = Tickets(_ticketsAddress);
        token = IERC20(_token);
        channelId = _channelId;
        channelHost = _channelHost;
        protocolTreasury = _treasury;
    }

    // Admin functions
    function startGame(
        uint256 _tradingEndTime,
        uint256 _endTime
    ) external onlyOwner {
        if (
            _tradingEndTime < block.number ||
            _endTime < block.number ||
            _endTime < _tradingEndTime
        ) revert InvalidParams();

        isPaused = false;
        tradingEndTime = _tradingEndTime;
        endTime = _endTime;

        emit GameStarted(_tradingEndTime, _endTime);
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
        if (block.number < endTime) revert GameNotOver();

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
        if (isPaused || block.number > tradingEndTime) revert GameNotActive();

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

        // Transfer fees
        if (referrer != address(0)) {
            uint256 referralFee = (price * referralFeePercent) / 1 ether;
            uint256 feeAmount = ((price * feePercent) / 1 ether) / 2;
            uint256 creatorFeeAmount = ((price * creatorFeePercent) / 1 ether) /
                2;

            token.transferFrom(msg.sender, protocolTreasury, feeAmount);
            token.transferFrom(msg.sender, channelHost, feeAmount);
            token.transferFrom(msg.sender, castCreator, creatorFeeAmount);
            token.transferFrom(msg.sender, referrer, referralFee);
        } else {
            uint256 feeAmount = (price * feePercent) / 1 ether;
            uint256 creatorFeeAmount = (price * creatorFeePercent) / 1 ether;

            token.transferFrom(msg.sender, protocolTreasury, feeAmount);
            token.transferFrom(msg.sender, channelHost, feeAmount);
            token.transferFrom(msg.sender, castCreator, creatorFeeAmount);
        }

        // Transfer payment
        token.transferFrom(
            msg.sender,
            address(this),
            (price * .8 ether) / 1 ether
        );

        // Mint ERC1155
        tickets.mint(msg.sender, castHash, amount);

        emit Purchased(
            msg.sender,
            castCreator,
            castHash,
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
        if (isPaused || block.number > tradingEndTime) revert GameNotActive();

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

        // Transfer fees
        if (referrer != address(0)) {
            uint256 referralFee = (price * referralFeePercent) / 1 ether;
            uint256 feeAmount = ((price * feePercent) / 1 ether) / 2;
            uint256 creatorFeeAmount = ((price * creatorFeePercent) / 1 ether) /
                2;

            token.transfer(protocolTreasury, feeAmount);
            token.transfer(channelHost, feeAmount);
            token.transfer(castCreator, creatorFeeAmount);
            token.transfer(referrer, referralFee);
        } else {
            uint256 feeAmount = (price * feePercent) / 1 ether;
            uint256 creatorFeeAmount = (price * creatorFeePercent) / 1 ether;

            token.transfer(protocolTreasury, feeAmount);
            token.transfer(channelHost, feeAmount);
            token.transfer(castCreator, creatorFeeAmount);
        }

        // Transfer payment
        token.transfer(msg.sender, (price * .8 ether) / 1 ether);

        // Burn ERC1155
        tickets.burn(msg.sender, castHash, amount);

        emit Sold(msg.sender, castCreator, castHash, referrer, amount, price);
    }
}
