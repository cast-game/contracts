// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tickets is ERC1155, Ownable {
    uint256 public latestTokenId;
    // cast hash -> token id
    mapping(string => uint256) public castTokenId;
    // token id -> uri
    mapping(uint256 => string) public uris;

    error NotOwner();

    constructor() ERC1155("") Ownable(msg.sender) {}

    function getTokenId() external returns (uint256) {
        return ++latestTokenId;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
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

    function mintTicket(
        address account,
        string memory castHash,
        uint256 amount
    ) external onlyOwner {
        uint256 tokenId = castTokenId[castHash];
        if (tokenId == 0) tokenId = ++latestTokenId;

        castTokenId[castHash] = tokenId;

        _mint(account, tokenId, amount, "");
    }

    function burnTicket(
        address account,
        string memory castHash,
        uint256 amount
    ) external onlyOwner {
        uint256 tokenId = castTokenId[castHash];
        if (tokenId == 0) revert NotOwner();

        _burn(account, tokenId, amount);
    }
}
