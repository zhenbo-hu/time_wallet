// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract ERC20TokenTest is Test {
    uint256 public immutable TOTAL_SUPPLY = 500 * 1e6;
    ERC20Token public usdt;

    function setUp() public {
        usdt = new ERC20Token("Tether USD", "USDT", 6, TOTAL_SUPPLY);
    }

    function testTransfer() public {
        usdt.transfer(
            address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
            50 * 1e6
        );
    }

    function testTransferMultiTimes() public {
        for (uint256 i; i < 100; i++) {
            usdt.transfer(
                address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
                5 * 1e6
            );
        }
    }
}
