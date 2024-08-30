// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/USDT.sol";

contract USDTTest is Test {
    USDT public usdt;

    function setUp() public {
        usdt = new USDT();
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
