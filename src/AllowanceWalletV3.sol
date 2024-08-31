// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./IERC20.sol";
import {AggregatorV3Interface} from "foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

contract AllowanceWalletV3 {
    error NotOwner();
    error InLastWithdraw();
    error WithdrawAmountLimitPerIntervalReached();
    error WithdrawAmountLimitPerTimeReached();
    error NoEnoughTokenAmount();

    struct WithdrawRecord {
        uint256 timestamp;
        uint256 amount;
    }

    WithdrawRecord[] private withdrawRecords;

    // price feed contract address info: https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
    // ERC20 token => price feed contract token/USD, like UNI/USD
    mapping(address => address) private tokenPriceContracts;

    bool private withdrawFlag;
    uint256 private tokenPrice;

    address public immutable OWNER;
    address public immutable BASIC_TOKEN_ADDRESS; // Basic token, example USDT

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

    modifier withdrawState(address token) {
        if (withdrawFlag) revert InLastWithdraw();

        withdrawFlag = true;
        tokenPrice = getTokenPrice(token);
        _;
        withdrawFlag = false;
    }

    modifier checkTokenAmount(address token, uint256 amount) {
        if (IERC20(token).balanceOf(address(this)) < amount)
            revert NoEnoughTokenAmount();
        _;
    }

    modifier checkWithdrawAmountLimitPerTime(address token, uint256 amount) {
        uint256 tokenValue = amount * tokenPrice;
        if (tokenValue > WITHDRAW_AMOUNT_LIMIT_PER_TIME)
            revert WithdrawAmountLimitPerTimeReached();
        _;
    }

    modifier checkWithdrawTimeIntervalAndAmount(
        address token,
        uint256 currentTime,
        uint256 amount
    ) {
        uint256 tokenValue = amount * tokenPrice;

        if (
            withdrawRecords[0].timestamp != 0 &&
            withdrawRecords[withdrawRecords[0].timestamp].timestamp +
                WITHDRAW_INTERVAL <=
            currentTime
        ) {
            uint256 i = withdrawRecords[0].timestamp;
            do {
                withdrawRecords[0].amount -= withdrawRecords[i++].amount;
            } while (
                i < withdrawRecords.length &&
                    withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <=
                    currentTime
            );

            if (i < withdrawRecords.length) {
                withdrawRecords[0] = WithdrawRecord(
                    i,
                    withdrawRecords[0].amount
                );
            } else {
                withdrawRecords[0] = WithdrawRecord(0, 0);
            }
        }

        if (
            withdrawRecords[0].amount + tokenValue >
            WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL
        ) revert WithdrawAmountLimitPerIntervalReached();

        _;
    }

    constructor(address basicTokenAddress) {
        OWNER = msg.sender;
        BASIC_TOKEN_ADDRESS = basicTokenAddress;
        withdrawRecords.push(WithdrawRecord(0, 0));
    }

    function withdraw(
        address token,
        uint256 amount
    )
        external
        onlyOwner
        withdrawState(token)
        checkTokenAmount(token, amount)
        checkWithdrawAmountLimitPerTime(token, amount)
        checkWithdrawTimeIntervalAndAmount(token, block.timestamp, amount)
    {
        uint256 tokenValue = amount * tokenPrice;

        withdrawRecords.push(WithdrawRecord(block.timestamp, tokenValue));

        withdrawRecords[0].amount += tokenValue;
        if (withdrawRecords[0].timestamp == 0)
            withdrawRecords[0].timestamp = withdrawRecords.length - 1;

        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, block.timestamp, tokenValue);
    }

    function addToken(
        address token,
        address tokenPriceContract
    ) external onlyOwner {
        tokenPriceContracts[token] = tokenPriceContract;
    }

    function getTokenPrice(address token) internal view returns (uint256) {
        AggregatorV3Interface priceContract = AggregatorV3Interface(
            tokenPriceContracts[token]
        );
        (, int256 price, , , ) = priceContract.latestRoundData();
        return uint256(price);
    }
}