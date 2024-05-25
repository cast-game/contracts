// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Degen", "DEGEN") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
