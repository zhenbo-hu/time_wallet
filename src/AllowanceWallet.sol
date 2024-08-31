// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./IERC20.sol";

contract AllowanceWallet {
    error NotOwner();
    error WithdrawAmountLimitPerIntervalReached();
    error WithdrawAmountLimitPerTimeReached();
    error NoEnoughTokenAmount();

    struct WithdrawRecord {
        uint256 timestamp;
        uint256 amount;
    }

    WithdrawRecord[] private withdrawRecords;

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

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner();
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
        uint256 currentWithdrawAmount = 0;
        uint256 i = withdrawRecords.length - 1;
        for (; i > 0; --i) {
            if (withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <= currentTime)
                break;
            if (
                currentWithdrawAmount + withdrawRecords[i].amount + amount >
                WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL
            ) revert WithdrawAmountLimitPerIntervalReached();
            currentWithdrawAmount += withdrawRecords[i].amount;
        }
        /* 方法1 End */

        /* 方法2 Begin */
        // uint256 lastestIndex = withdrawRecords[0].timestamp;
        // uint256 lastestAmounts = withdrawRecords[0].amount;
        // uint256 recordsLength = withdrawRecords.length;

        // if (
        //     lastestIndex != 0 &&
        //     withdrawRecords[lastestIndex].timestamp + WITHDRAW_INTERVAL <=
        //     currentTime
        // ) {
        //     uint256 i = lastestIndex;
        //     do {
        //         lastestAmounts -= withdrawRecords[i++].amount;
        //     } while (
        //         i < recordsLength &&
        //             withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <=
        //             currentTime
        //     );

        //     if (i < recordsLength) {
        //         withdrawRecords[0] = WithdrawRecord(i, lastestAmounts);
        //     } else {
        //         withdrawRecords[0] = WithdrawRecord(0, 0);
        //     }
        // }

        // if (lastestAmounts + amount > WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL)
        //     revert WithdrawAmountLimitPerIntervalReached();
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
        checkWithdrawAmountLimitPerTime(amount)
        checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
    {
        withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

        /* 方法2 Begin */
        // withdrawRecords[0].amount += amount;
        // if (withdrawRecords[0].timestamp == 0)
        //     withdrawRecords[0].timestamp = withdrawRecords.length - 1;
        /* 方法2 End */

        IERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, block.timestamp, amount);
    }
}
