// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";
import {AllowanceWallet} from "../src/AllowanceWallet.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract AllowanceWalletTest is Test {
    uint256 public immutable TOTAL_SUPPLY = 500 * 1e6;

    ERC20Token public usdt;
    AllowanceWallet public allowanceWallet;

    function setUp() public {
        usdt = new ERC20Token("Tether USD", "USDT", 6, TOTAL_SUPPLY);
        allowanceWallet = new AllowanceWallet(address(usdt));

        usdt.transfer(address(allowanceWallet), TOTAL_SUPPLY);
    }

    function testConstructor() public {
        AllowanceWallet localAllowanceWallet = new AllowanceWallet(
            address(usdt)
        );

        assertEq(localAllowanceWallet.OWNER(), address(this));
        assertEq(localAllowanceWallet.TOKEN_ADDRESS(), address(usdt));
    }

    function testWithdraw() public {
        allowanceWallet.withdraw(50 * 1e6);
    }

    function testWithdrawLess100UsdtOneTimeLess1DaySuccessful() public {
        vm.expectEmit(true, false, false, true);
        emit AllowanceWallet.Withdraw(address(this), block.timestamp, 50 * 1e6);

        allowanceWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);
    }

    function testWithdrawOver50UsdtOneTimeRevert() public {
        vm.expectRevert(
            AllowanceWallet.WithdrawAmountLimitPerTimeReached.selector
        );

        allowanceWallet.withdraw(51 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0);
    }

    function testWithdrawRevertNotOwner() public {
        vm.prank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        vm.expectRevert(AllowanceWallet.NotOwner.selector);

        allowanceWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0);
    }

    function testWithdrawLess100UsdtMultiTimeLess1DaySuccessful() public {
        allowanceWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);

        allowanceWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimesLess1DayRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        vm.warp(0);

        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 20 * 1e6);

        vm.warp(1 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 40 * 1e6);

        vm.warp(2 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 60 * 1e6);

        vm.warp(3 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);

        vm.expectRevert(
            AllowanceWallet.WithdrawAmountLimitPerIntervalReached.selector
        );
        vm.warp(4 hours);

        allowanceWallet.withdraw(21 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimesOver1DayRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        vm.warp(0);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 20 * 1e6);

        vm.warp(2 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 40 * 1e6);

        vm.warp(6 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 60 * 1e6);

        vm.warp(12 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);

        vm.warp(22 hours);
        allowanceWallet.withdraw(20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);

        vm.warp(27 hours);
        allowanceWallet.withdraw(30 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);

        vm.warp(29 hours);
        vm.expectRevert(
            AllowanceWallet.WithdrawAmountLimitPerIntervalReached.selector
        );
        allowanceWallet.withdraw(11 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);
    }

    function testWithdrawOver100UsdtMultiTimeOver1DaySuccessful() public {
        vm.warp(0);
        allowanceWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);

        vm.warp(1 hours);
        allowanceWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);

        vm.warp(1 days + 1 hours);
        allowanceWallet.withdraw(50 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 150 * 1e6);

        vm.warp(1 days + 2 hours);
        allowanceWallet.withdraw(50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 200 * 1e6);
    }

    function testWithdrawAllUsdtMultiTimeOver1DaySuccessful() public {
        uint256 currentTimestamp = 0;
        vm.warp(currentTimestamp);

        for (uint256 i = 0; i < 5; ++i) {
            for (uint256 j = 0; j < 10; ++j) {
                allowanceWallet.withdraw(10 * 1e6);
            }

            assertEq(usdt.balanceOf(address(this)), (i + 1) * 10 * 10 * 1e6);

            currentTimestamp += 1 days;
            vm.warp(currentTimestamp);
        }
    }
}
