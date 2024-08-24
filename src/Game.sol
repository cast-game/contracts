// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// import "./Tickets.sol";

contract Game is Ownable {
    using ECDSA for bytes32;

    // Tickets public tickets;

    address public protocolTreasury;
    address public channelHost;

    /// @notice transaction fees
    uint256 public feePercent = 0.05 ether;
    uint256 public referralFeePercent = 0.1 ether;
    uint256 public creatorFeePercent = 0.1 ether;

    bool public isPaused;
    uint256 public tradingEndTime;
    uint256 public endTime;

    mapping(address => mapping(string => uint256)) public balance;
    mapping(string => uint256) public supply;

    // Nonce to ensure hashes are unique per transaction
    mapping(string => uint256) public nonce;

    event Purchased(
        address indexed buyer,
        address indexed castCreator,
        uint256 indexed senderFid,
        string castHash,
        address referrer,
        uint256 amount,
        uint256 price
    );

    event Sold(
        address indexed seller,
        address indexed castCreator,
        uint256 indexed senderFid,
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
    error InsufficientBalance();

    constructor(
        address _channelHost,
        // address _ticketsAddress,
        address _treasury
    ) Ownable(msg.sender) {
        // tickets = Tickets(_ticketsAddress);
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
            (bool success, ) = winners[i].call{value: amounts[i]}("");
            // remove if gas too high
            require(success, "Transfer failed");
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
        bytes memory data,
        bytes memory signature
    ) external payable {
        (
            address castCreator,
            uint256 senderFid,
            uint256 amount,
            uint256 price,
            address referrer
        ) = abi.decode(data, (address, uint256, uint256, uint256, address));

        if (msg.value != price) revert InsufficientPayment();
        if (isPaused || block.number > tradingEndTime) revert GameNotActive();

        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                senderFid,
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

            (bool success0, ) = protocolTreasury.call{value: feeAmount}("");
            (bool success1, ) = channelHost.call{value: feeAmount}("");
            (bool success2, ) = castCreator.call{value: creatorFeeAmount}("");
            (bool success3, ) = referrer.call{value: referralFee}("");
            require(
                success0 && success1 && success2 && success3,
                "Transfer failed"
            );
        } else {
            uint256 feeAmount = (price * feePercent) / 1 ether;
            uint256 creatorFeeAmount = (price * creatorFeePercent) / 1 ether;

            (bool success0, ) = protocolTreasury.call{value: feeAmount}("");
            (bool success1, ) = channelHost.call{value: feeAmount}("");
            (bool success2, ) = castCreator.call{value: creatorFeeAmount}("");
            require(success0 && success1 && success2, "Transfer failed");
        }

        // Mint ERC1155
        // tickets.mint(msg.sender, castHash, amount);
        balance[msg.sender][castHash] += amount;
        supply[castHash] += amount;

        emit Purchased(
            msg.sender,
            castCreator,
            senderFid,
            castHash,
            referrer,
            amount,
            price
        );
    }

    function sell(
        string memory castHash,
        bytes memory data,
        bytes memory signature
    ) external {
        (
            address castCreator,
            uint256 senderFid,
            uint256 amount,
            uint256 price,
            address referrer
        ) = abi.decode(data, (address, uint256, uint256, uint256, address));
        if (isPaused || block.number > tradingEndTime) revert GameNotActive();
        if (balance[msg.sender][castHash] < amount) revert InsufficientBalance();

        bytes32 hash = keccak256(
            abi.encodePacked(
                castHash,
                castCreator,
                senderFid,
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

            (bool success0, ) = protocolTreasury.call{value: feeAmount}("");
            (bool success1, ) = channelHost.call{value: feeAmount}("");
            (bool success2, ) = castCreator.call{value: creatorFeeAmount}("");
            (bool success3, ) = referrer.call{value: referralFee}("");
            require(
                success0 && success1 && success2 && success3,
                "Transfer failed"
            );
        } else {
            uint256 feeAmount = (price * feePercent) / 1 ether;
            uint256 creatorFeeAmount = (price * creatorFeePercent) / 1 ether;

            (bool success0, ) = protocolTreasury.call{value: feeAmount}("");
            (bool success1, ) = channelHost.call{value: feeAmount}("");
            (bool success2, ) = castCreator.call{value: creatorFeeAmount}("");
            require(success0 && success1 && success2, "Transfer failed");
        }

        // Transfer payment
        (bool success, ) = msg.sender.call{value: (price * .8 ether) / 1 ether}(
            ""
        );
        require(success, "Transfer failed");

        // Burn ERC1155
        // tickets.burn(msg.sender, castHash, amount);
        balance[msg.sender][castHash] -= amount;
        supply[castHash] -= amount;

        emit Sold(
            msg.sender,
            castCreator,
            senderFid,
            castHash,
            referrer,
            amount,
            price
        );
    }
}
