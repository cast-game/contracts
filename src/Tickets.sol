// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tickets is ERC1155, Ownable {
    address public minter;
    uint256 public latestTokenId;

    // cast hash -> token id
    mapping(string => uint256) public castTokenId;
    // token id -> cast hash
    mapping(uint256 => string) public castHashes;
    // token id -> supply
    mapping(uint256 => uint256) public supply;
    // token id -> uri
    mapping(uint256 => string) public uris;

    error NotAuthorized();

    constructor() ERC1155("") Ownable(msg.sender) {}

    function setMinter(address newMinter) external onlyOwner {
        minter = newMinter;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return uris[tokenId];
    }

    function setTokenUri(
        uint256 _tokenId,
        string memory _uri
    ) external onlyOwner {
        uris[_tokenId] = _uri;
    }

    function mint(
        address account,
        string memory castHash,
        uint256 amount
    ) external {
        if (msg.sender != minter) revert NotAuthorized();
        uint256 tokenId = castTokenId[castHash];
        if (tokenId == 0) tokenId = ++latestTokenId;

        castTokenId[castHash] = tokenId;
        castHashes[tokenId] = castHash;
        supply[tokenId] += amount;

        _mint(account, tokenId, amount, "");
    }

    function burn(
        address account,
        string memory castHash,
        uint256 amount
    ) external {
        if (msg.sender != minter) revert NotAuthorized();
        uint256 tokenId = castTokenId[castHash];
        supply[tokenId] -= amount;

        _burn(account, tokenId, amount);
    }
}
