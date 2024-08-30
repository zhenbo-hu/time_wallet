// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/USDT.sol";

contract USDTTest is Test {
    USDT usdt;

    function setUp() public {
        usdt = new USDT();
    }

    function testTransfer() public {
        usdt.transfer(
            address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
            100 * 1e6
        );
    }
}
