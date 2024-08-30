// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";
import {TimeWallet} from "../src/TimeWallet.sol";
import {USDT} from "../src/USDT.sol";

contract TimeWalletTest is Test {
    USDT public usdt;
    TimeWallet public timeWallet;

    function setUp() public {
        usdt = new USDT();
        timeWallet = new TimeWallet(address(usdt));
        usdt.transfer(address(timeWallet), 500 * 1e6);
    }

    function testConstructor() public {
        TimeWallet localTimeWallet = new TimeWallet(address(usdt));

        assertEq(localTimeWallet.OWNER(), address(this));
        assertEq(localTimeWallet.TOKEN_ADDRESS(), address(usdt));
    }

    function testWithdraw() public {
        timeWallet.withdraw(50 * 1e6);
    }

    function testWithdrawLess100UsdtOneTimeLess1DaySuccessful() public {
        vm.expectEmit(true, false, false, true);
        emit TimeWallet.Withdraw(address(this), block.timestamp, 50 * 1e6);

        timeWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);
    }

    function testWithdrawOver50UsdtOneTimeRevert() public {
        vm.expectRevert(TimeWallet.WithdrawAmountLimitPerTimeReached.selector);

        timeWallet.withdraw(51 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0);
    }

    function testWithdrawRevertNotOwner() public {
        vm.prank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        vm.expectRevert(TimeWallet.NotOwner.selector);

        timeWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0);
    }

    function testWithdrawLess100UsdtMultiTimeLess1DaySuccessful() public {
        timeWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);

        timeWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimesLess1DayRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        vm.warp(0);

        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 20 * 1e6);

        vm.warp(1 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 40 * 1e6);

        vm.warp(2 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 60 * 1e6);

        vm.warp(3 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);

        vm.expectRevert(
            TimeWallet.WithdrawAmountLimitPerIntervalReached.selector
        );
        vm.warp(4 hours);

        timeWallet.withdraw(21 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimesOver1DayRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        vm.warp(0);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 20 * 1e6);

        vm.warp(2 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 40 * 1e6);

        vm.warp(6 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 60 * 1e6);

        vm.warp(12 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);

        vm.warp(22 hours);
        timeWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);

        vm.warp(27 hours);
        timeWallet.withdraw(30 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);

        vm.warp(29 hours);
        vm.expectRevert(
            TimeWallet.WithdrawAmountLimitPerIntervalReached.selector
        );
        timeWallet.withdraw(11 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimeOver1DaySuccessful() public {
        vm.warp(0);
        timeWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);

        vm.warp(1 hours);
        timeWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);

        vm.warp(1 days + 1 hours);
        timeWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 150 * 1e6);

        vm.warp(1 days + 2 hours);
        timeWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 200 * 1e6);
    }

    function testWithdrawAllUsdtMultiTimeOver1DaySuccessful() public {
        uint256 currentTimestamp = 0;
        vm.warp(currentTimestamp);

        for (uint256 i = 0; i < 5; ++i) {
            for (uint256 j = 0; j < 10; ++j) {
                timeWallet.withdraw(10 * 1e6);
            }

            assertEq(usdt.balanceOf(address(this)), (i + 1) * 10 * 10 * 1e6);

            currentTimestamp += 1 days;
            vm.warp(currentTimestamp);
        }
    }

    function testWithdrawAllUsdtMultiTimeOver1DayRevertNoEnoughTokenAmount()
        public
    {
        uint256 currentTimestamp = 0;
        vm.warp(currentTimestamp);

        for (uint256 i = 0; i < 5; ++i) {
            for (uint256 j = 0; j < 10; ++j) {
                timeWallet.withdraw(10 * 1e6);
            }

            assertEq(usdt.balanceOf(address(this)), (i + 1) * 10 * 10 * 1e6);
            currentTimestamp += 1 days;
            vm.warp(currentTimestamp);
        }

        assertEq(usdt.balanceOf(address(this)), 500 * 1e6);

        vm.expectRevert(TimeWallet.NoEnoughTokenAmount.selector);

        timeWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 500 * 1e6);
    }
}
