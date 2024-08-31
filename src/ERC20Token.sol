// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";

contract ERC20Token is ERC20 {
    uint256 private immutable TOTAL_SUPPLY = 500 * 1e6;
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) ERC20(name, symbol, decimals) {
        _mint(msg.sender, totalSupply);
    }
}
