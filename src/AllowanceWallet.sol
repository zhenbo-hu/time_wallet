// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./IERC20.sol";

contract AllowanceWallet {
    error NotOwner();
    error WithdrawAmountLimitPerIntervalReached();
    error WithdrawAmountLimitPerTimeReached();
    error NoEnoughTokenAmount();
    error WithdrawInProgress();
    error InsufficientBalance();

    struct WithdrawRecord {
        uint256 timestamp;
        uint256 amount;
    }

    WithdrawRecord[] private withdrawRecords;
    uint256 private tokenAmount;
    bool private lock;

    address public immutable OWNER;
    address public immutable TOKEN_ADDRESS;

    uint256 private constant WITHDRAW_INTERVAL = 1 days;
    uint256 private constant WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL = 100 * 1e6;
    uint256 private constant WITHDRAW_AMOUNT_LIMIT_PER_TIME = 50 * 1e6;

    event Withdraw(
        address indexed to,
        uint256 withdrawTimestamp,
        uint256 amount
    );

    event Deposit(address indexed from, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner();
        _;
    }

    modifier checkLock() {
        if (lock) revert WithdrawInProgress();
        lock = true;
        _;
        lock = false;
    }

    modifier checkAmountEfficient(uint256 amount) {
        if (amount > tokenAmount) revert NoEnoughTokenAmount();
        _;
    }

    modifier checkWithdrawAmountLimitPerTime(uint256 amount) {
        if (amount > WITHDRAW_AMOUNT_LIMIT_PER_TIME)
            revert WithdrawAmountLimitPerTimeReached();
        _;
    }

    modifier checkWithdrawTimeIntervalAndAmount(
        uint256 currentTime,
        uint256 amount
    ) {
        /* 方法1 Begin */
        // uint256 currentWithdrawAmount = 0;
        // uint256 i = withdrawRecords.length - 1;
        // for (; i > 0; --i) {
        //     if (withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <= currentTime)
        //         break;
        //     if (
        //         currentWithdrawAmount + withdrawRecords[i].amount + amount >
        //         WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL
        //     ) revert WithdrawAmountLimitPerIntervalReached();
        //     currentWithdrawAmount += withdrawRecords[i].amount;
        // }
        /* 方法1 End */

        /* 方法2 Begin */
        uint256 latestIndex = withdrawRecords[0].timestamp;
        uint256 latestAmounts = withdrawRecords[0].amount;
        uint256 recordsLength = withdrawRecords.length;

        if (
            latestIndex != 0 &&
            withdrawRecords[latestIndex].timestamp + WITHDRAW_INTERVAL <=
            currentTime
        ) {
            uint256 i = latestIndex;
            do {
                latestAmounts -= withdrawRecords[i++].amount;
            } while (
                i < recordsLength &&
                    withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <=
                    currentTime
            );

            if (i < recordsLength) {
                withdrawRecords[0] = WithdrawRecord(i, latestAmounts);
            } else {
                withdrawRecords[0] = WithdrawRecord(0, 0);
            }
        }

        if (latestAmounts + amount > WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL)
            revert WithdrawAmountLimitPerIntervalReached();
        /* 方法2 End */

        _;
    }

    constructor(address tokenAddress) {
        OWNER = msg.sender;
        TOKEN_ADDRESS = tokenAddress;
        withdrawRecords.push(WithdrawRecord(0, 0));
    }

    function withdraw(
        uint256 amount
    )
        external
        onlyOwner
        checkLock
        checkAmountEfficient(amount)
        checkWithdrawAmountLimitPerTime(amount)
        checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
    {
        withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

        /* 方法2 Begin */
        withdrawRecords[0].amount += amount;
        if (withdrawRecords[0].timestamp == 0) {
            withdrawRecords[0].timestamp = withdrawRecords.length - 1;
            withdrawRecords[0].amount = amount;
        }
        /* 方法2 End */

        IERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, block.timestamp, amount);
    }

    function deposit(uint256 amount) external onlyOwner {
        if (
            IERC20(TOKEN_ADDRESS).balanceOf(address(msg.sender)) <
            tokenAmount + amount
        ) revert InsufficientBalance();
        tokenAmount += amount;
        IERC20(TOKEN_ADDRESS).transferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }
}
