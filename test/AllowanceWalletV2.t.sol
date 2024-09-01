// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";
import {AllowanceWalletV2} from "../src/AllowanceWalletV2.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract AllowanceWalletV3Test is Test {
    uint256 public immutable TOTAL_SUPPLY = 500 * 1e6;

    AllowanceWalletV2 public allowanceWallet;
    ERC20Token public usdt;
    ERC20Token public wEth;
    ERC20Token public uni;

    function setUp() public {
        usdt = new ERC20Token("Tether USD", "USDT", 6, TOTAL_SUPPLY);
        wEth = new ERC20Token("Wrap Ether", "wEth", 18, TOTAL_SUPPLY * 1e12);
        allowanceWallet = new AllowanceWalletV2();

        usdt.approve(address(allowanceWallet), TOTAL_SUPPLY);
        allowanceWallet.deposit(address(usdt), TOTAL_SUPPLY);

        wEth.approve(address(allowanceWallet), TOTAL_SUPPLY * 1e12);
        allowanceWallet.deposit(address(wEth), TOTAL_SUPPLY * 1e12);

        allowanceWallet.setTokenRule(
            address(usdt),
            1 days,
            100 * 1e6,
            50 * 1e6
        );

        allowanceWallet.setTokenRule(
            address(wEth),
            30 days,
            1 * 1e18,
            200 * 1e15
        );
    }

    function testConstructor() public {
        AllowanceWalletV2 localAllowanceWallet = new AllowanceWalletV2();

        assertEq(localAllowanceWallet.OWNER(), address(this));
    }

    function testDepositSuccessful() public {
        ERC20Token localUsdt = new ERC20Token(
            "Tether USD",
            "USDT",
            6,
            TOTAL_SUPPLY
        );
        AllowanceWalletV2 localAllowanceWallet = new AllowanceWalletV2();

        localUsdt.approve(address(localAllowanceWallet), TOTAL_SUPPLY);
        localAllowanceWallet.deposit(address(localUsdt), TOTAL_SUPPLY);

        assertEq(
            localUsdt.balanceOf(address(localAllowanceWallet)),
            TOTAL_SUPPLY
        );
    }

    function testDepositRevertInsufficientBalance() public {
        vm.prank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        ERC20Token localUsdt = new ERC20Token(
            "Tether USD",
            "USDT",
            6,
            TOTAL_SUPPLY
        );
        AllowanceWalletV2 localAllowanceWallet = new AllowanceWalletV2();

        localUsdt.approve(address(localAllowanceWallet), TOTAL_SUPPLY);
        vm.expectRevert(AllowanceWalletV2.InsufficientBalance.selector);

        localAllowanceWallet.deposit(address(localUsdt), TOTAL_SUPPLY);

        assertEq(localUsdt.balanceOf(address(localAllowanceWallet)), 0);
    }

    function testSetTokenRule() public {
        AllowanceWalletV2 localAllowanceWallet = new AllowanceWalletV2();

        localAllowanceWallet.setTokenRule(
            address(usdt),
            1 days,
            100 * 1e6,
            50 * 1e6
        );

        bool isSet;
        uint256 withdrawInterval;
        uint256 withdrawAmountLimitPerInterval;
        uint256 withdrawAmountLimitPerTime;

        (
            isSet,
            withdrawInterval,
            withdrawAmountLimitPerInterval,
            withdrawAmountLimitPerTime
        ) = localAllowanceWallet.getTokenRule(address(usdt));

        assertEq(isSet, true);
        assertEq(withdrawInterval, 1 days);
        assertEq(withdrawAmountLimitPerInterval, 100 * 1e6);
        assertEq(withdrawAmountLimitPerTime, 50 * 1e6);
    }

    function testSetTokenRuleRevertExistTokenRule() public {
        vm.expectRevert(AllowanceWalletV2.ExistTokenRule.selector);

        allowanceWallet.setTokenRule(
            address(usdt),
            1 days,
            100 * 1e6,
            50 * 1e6
        );
    }

    function testWithdrawRevertNotOwner() public {
        vm.prank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        vm.expectRevert(AllowanceWalletV2.NotOwner.selector);

        allowanceWallet.withdraw(address(usdt), 50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0);
    }

    function testWithdrawLess50UsdtOneTimeSuccessful() public {
        assertEq(usdt.balanceOf(address(this)), 0);

        allowanceWallet.withdraw(address(usdt), 50 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 50 * 1e6);
    }

    function testWithdrawLess100FinneyWETHOneTimeSuccessful() public {
        assertEq(wEth.balanceOf(address(this)), 0);

        allowanceWallet.withdraw(address(wEth), 100 * 1e15);

        assertEq(wEth.balanceOf(address(this)), 100 * 1e15);
    }

    function testWithdrawOver50UsdtOneTimeRevertWithdrawAmountLimitPerTimeReached()
        public
    {
        assertEq(usdt.balanceOf(address(this)), 0);
        vm.expectRevert(
            AllowanceWalletV2.WithdrawAmountLimitPerTimeReached.selector
        );

        allowanceWallet.withdraw(address(usdt), 60 * 1e6);

        assertEq(usdt.balanceOf(address(this)), 0 * 1e6);
    }

    function testWithdrawOver1EtherWETHMultiTimesRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        assertEq(wEth.balanceOf(address(this)), 0);

        vm.warp(0);
        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 200 * 1e15);

        vm.warp(1 hours);
        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 400 * 1e15);

        vm.warp(1 days);
        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 600 * 1e15);

        vm.warp(1 days + 5 hours);
        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 800 * 1e15);

        vm.warp(1 weeks);
        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 1 * 1e18);

        vm.warp(2 weeks);

        vm.expectRevert(
            AllowanceWalletV2.WithdrawAmountLimitPerIntervalReached.selector
        );

        allowanceWallet.withdraw(address(wEth), 200 * 1e15);
        assertEq(wEth.balanceOf(address(this)), 1 * 1e18);
    }

    function testWithdrawNotExistTokenRuleRevert() public {
        vm.expectRevert();

        allowanceWallet.withdraw(address(uni), 100);
    }

    function testWithdrawAllUsdtMultiTimeOver1DaySuccessful() public {
        uint256 currentTimestamp = 0;
        vm.warp(currentTimestamp);

        for (uint256 i = 0; i < 5; ++i) {
            for (uint256 j = 0; j < 10; ++j) {
                allowanceWallet.withdraw(address(usdt), 10 * 1e6);
            }

            assertEq(usdt.balanceOf(address(this)), (i + 1) * 10 * 10 * 1e6);

            currentTimestamp += 1 days;
            vm.warp(currentTimestamp);
        }
    }

    function testWithdrawOver100UsdtMultiTimesOver1DayRevertWithdrawAmountLimitPerIntervalReached()
        public
    {
        vm.warp(0);
        allowanceWallet.withdraw(address(usdt), 20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 20 * 1e6);

        vm.warp(2 hours);
        allowanceWallet.withdraw(address(usdt), 20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 40 * 1e6);

        vm.warp(6 hours);
        allowanceWallet.withdraw(address(usdt), 20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 60 * 1e6);

        vm.warp(12 hours);
        allowanceWallet.withdraw(address(usdt), 20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 80 * 1e6);

        vm.warp(22 hours);
        allowanceWallet.withdraw(address(usdt), 20 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 100 * 1e6);

        vm.warp(27 hours);
        allowanceWallet.withdraw(address(usdt), 30 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);

        vm.warp(29 hours);
        vm.expectRevert(
            AllowanceWalletV2.WithdrawAmountLimitPerIntervalReached.selector
        );
        allowanceWallet.withdraw(address(usdt), 11 * 1e6);
        assertEq(usdt.balanceOf(address(this)), 130 * 1e6);
    }
}
