// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";

contract USDT is ERC20 {
    uint256 private immutable TOTAL_SUPPLY = 500 * 1e6;
    constructor() ERC20("Tether USD", "USDT", 18) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
