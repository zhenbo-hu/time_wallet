// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./IERC20.sol";

contract AllowanceWalletV2 {
    error NotOwner();
    error WithdrawAmountLimitPerIntervalReached();
    error WithdrawAmountLimitPerTimeReached();
    error NoEnoughTokenAmount();
    error ExistTokenRule();
    error NotExistTokenRule();

    struct WithdrawRecord {
        uint256 timestamp;
        uint256 amount;
    }

    struct TokenWithdrawRule {
        bool isSet;
        uint256 withdrawInterval;
        uint256 withdrawAmountLimitPerInterval;
        uint256 withdrawAmountLimitPerTime;
    }

    mapping(address => TokenWithdrawRule) private tokenWithdrawRules;
    mapping(address => WithdrawRecord[]) private withdrawRecords;

    address public immutable OWNER;

    event Withdraw(
        address indexed to,
        uint256 withdrawTimestamp,
        uint256 amount
    );

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner();
        _;
    }

    modifier checkTokenRule(address token) {
        if (tokenWithdrawRules[token].isSet) revert ExistTokenRule();
        _;
    }

    modifier checkTokenAmount(address token, uint256 amount) {
        if (IERC20(token).balanceOf(address(this)) < amount)
            revert NoEnoughTokenAmount();
        _;
    }

    modifier checkTokenWithdrawRule(
        address token,
        uint256 currentTime,
        uint256 amount
    ) {
        if (!tokenWithdrawRules[token].isSet) revert NotExistTokenRule();

        if (amount > tokenWithdrawRules[token].withdrawAmountLimitPerTime)
            revert WithdrawAmountLimitPerTimeReached();

        if (
            withdrawRecords[token][0].timestamp != 0 &&
            withdrawRecords[token][withdrawRecords[token][0].timestamp]
                .timestamp +
                tokenWithdrawRules[token].withdrawInterval <=
            currentTime
        ) {
            uint256 i = withdrawRecords[token][0].timestamp;
            do {
                withdrawRecords[token][0].amount -= withdrawRecords[token][i++]
                    .amount;
            } while (
                i < withdrawRecords[token].length &&
                    withdrawRecords[token][i].timestamp +
                        tokenWithdrawRules[token].withdrawInterval <=
                    currentTime
            );

            if (i < withdrawRecords[token].length) {
                withdrawRecords[token][0] = WithdrawRecord(
                    i,
                    withdrawRecords[token][0].amount
                );
            } else {
                withdrawRecords[token][0] = WithdrawRecord(0, 0);
            }
        }

        if (
            withdrawRecords[token][0].amount + amount >
            tokenWithdrawRules[token].withdrawAmountLimitPerInterval
        ) revert WithdrawAmountLimitPerIntervalReached();

        _;
    }

    constructor() {
        OWNER = msg.sender;
    }

    function withdraw(
        address token,
        uint256 amount
    )
        external
        onlyOwner
        checkTokenAmount(token, amount)
        checkTokenWithdrawRule(token, block.timestamp, amount)
    {
        withdrawRecords[token].push(WithdrawRecord(block.timestamp, amount));

        withdrawRecords[token][0].amount += amount;
        if (withdrawRecords[token][0].timestamp == 0)
            withdrawRecords[token][0].timestamp =
                withdrawRecords[token].length -
                1;

        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, block.timestamp, amount);
    }

    function setTokenRule(
        address token,
        uint256 withdrawInterval,
        uint256 withdrawAmountLimitPerInterval,
        uint256 withdrawAmountLimitPerTime
    ) external onlyOwner checkTokenRule(token) {
        tokenWithdrawRules[token] = TokenWithdrawRule(
            true,
            withdrawInterval,
            withdrawAmountLimitPerInterval,
            withdrawAmountLimitPerTime
        );

        withdrawRecords[token].push(WithdrawRecord(0, 0));
    }

    function getTokenRule(
        address token
    ) external view returns (bool, uint256, uint256, uint256) {
        return (
            tokenWithdrawRules[token].isSet,
            tokenWithdrawRules[token].withdrawInterval,
            tokenWithdrawRules[token].withdrawAmountLimitPerInterval,
            tokenWithdrawRules[token].withdrawAmountLimitPerTime
        );
    }
}
