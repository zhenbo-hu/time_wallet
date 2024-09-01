# 钱包合约

- [钱包合约](#钱包合约)
  - [V1](#v1)
    - [1.1 功能](#11-功能)
    - [1.2 核心逻辑](#12-核心逻辑)
      - [方法 1](#方法-1)
      - [方法 2](#方法-2)
  - [V2](#v2)
    - [2.1 功能](#21-功能)
    - [2.2 核心逻辑](#22-核心逻辑)
  - [gas 消耗分析](#gas-消耗分析)
    - [ERC20 gas report](#erc20-gas-report)
    - [V1 方法 1 gas report](#v1-方法-1-gas-report)
    - [V1 方法 2 gas report](#v1-方法-2-gas-report)
    - [V2 gas report](#v2-gas-report)
  - [单元测试结果](#单元测试结果)
  - [V3](#v3)
    - [3.1 功能](#31-功能)
    - [3.2 核心逻辑](#32-核心逻辑)

## V1

### 1.1 功能

- Owner 通过 `deposit` 方法向合约中存入 token
- Owner 可以通过 `withdraw` 方法提取钱包中的 token
- 每 24 小时提取限制总额度为 `100 * 1e6`
- 单次提取限制额度为 `50 * 1e6`

### 1.2 核心逻辑

通过多个 `modifier` 来检查资金提取的时间间隔、每次提取金额、24 小时内提取总金额等信息。

`checkTokenAmount` 用于检查当前合约是否拥有所需数量的 token

```solidity
modifier checkTokenAmount(uint256 amount) {
    if (ERC20(TOKEN_ADDRESS).balanceOf(address(this)) < amount)
        revert NoEnoughTokenAmount();
    _;
}
```

`checkWithdrawAmountLimitPerTime` 用于检查是否超过单次提取额度上限

```solidity
modifier checkWithdrawAmountLimitPerTime(uint256 amount) {
    if (amount > WITHDRAW_AMOUNT_LIMIT_PER_TIME)
        revert WithdrawAmountLimitPerTimeReached();
    _;
}
```

`checkWithdrawTimeIntervalAndAmount` 用于检查是否满足过去 24 小时总提取额度限制

定义 `WithdrawRecord` 结构体和 `WithdrawRecord[] private withdrawRecords;` 状态变量，用于记录每次提取的时间戳和金额

```solidity
struct WithdrawRecord {
    uint256 timestamp;
    uint256 amount;
}

WithdrawRecord[] private withdrawRecords;
```

#### 方法 1

每次提取时，从 `withdrawRecords` 数组中倒序遍历，直到找到最近一次提取的时间戳加上 `WITHDRAW_INTERVAL` 小于等于当前时间戳的记录，或者遍历完整个数组。

每次都需遍历数组，时间复杂度为 $O(n)$

**注意**：为防止倒序查找时数组越界，`index=0` 在初始化合约时赋值为空值，真正的提取记录从 1 开始

```solidity
modifier checkWithdrawTimeIntervalAndAmount(
    uint256 currentTime,
    uint256 amount
) {
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

    _;
}

function withdraw(
    uint256 amount
)
    external
    onlyOwner
    checkTokenAmount(amount)
    checkWithdrawAmountLimitPerTime(amount)
    checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
{
    withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

    ERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
    emit Withdraw(msg.sender, block.timestamp, amount);
}
```

#### 方法 2

利用 `index=0` 没有被用到的特点，用于记录上一次提取时同一天的全部提取金额和最初提取记录所在的 index。这样对于在 24 小时内的提取行为，不需要遍历数组，可以直接判断。当超过 24 小时时，再遍历数组，更新数据。

理想情况下，每次均可在固定操作步骤内得到结果，时间复杂度为 $O(1)$

最坏情况下，需要遍历数组才能够得到结果，时间复杂度为 $O(n)$

```solidity
modifier checkWithdrawTimeIntervalAndAmount(
    uint256 currentTime,
    uint256 amount
) {
    uint256 lastestIndex = withdrawRecords[0].timestamp;
    uint256 lastestAmounts = withdrawRecords[0].amount;
    uint256 recordsLength = withdrawRecords.length;

    if (
        lastestIndex != 0 &&
        withdrawRecords[lastestIndex].timestamp + WITHDRAW_INTERVAL <=
        currentTime
    ) {
        uint256 i = lastestIndex;
        do {
            lastestAmounts -= withdrawRecords[i++].amount;
        } while (
            i < recordsLength &&
                withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <=
                currentTime
        );

        if (i < recordsLength) {
            withdrawRecords[0] = WithdrawRecord(i, lastestAmounts);
        } else {
            withdrawRecords[0] = WithdrawRecord(0, 0);
        }
    }

    if (lastestAmounts + amount > WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL)
        revert WithdrawAmountLimitPerIntervalReached();

    _;
}

function withdraw(
    uint256 amount
)
    external
    onlyOwner
    checkTokenAmount(amount)
    checkWithdrawAmountLimitPerTime(amount)
    checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
{
    withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

    withdrawRecords[0].amount += amount;
    if (withdrawRecords[0].timestamp == 0)
        withdrawRecords[0].timestamp = withdrawRecords.length - 1;


    ERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
    emit Withdraw(msg.sender, block.timestamp, amount);
}
```

## V2

### 2.1 功能

在 V1 方法 2 的基础上，增加了对多币种的支持（ERC20），每个币种单独设定提取规则。

- Owner 通过 `deposit` 方法向合约中存入不同的 token
- Owner 通过 `withdraw` 方法从合约中提取不同的 token
- Owner 通过 `setTokenRule` 方法设定对不同 token 的提取规则

### 2.2 核心逻辑

定义 `TokenWithdrawRule` 结构体，用于记录每个币种的提现规则。

```solidity
struct TokenWithdrawRule {
    bool isSet;
    uint256 withdrawInterval;
    uint256 withdrawAmountLimitPerInterval;
    uint256 withdrawAmountLimitPerTime;
}

mapping(address => TokenWithdrawRule) private tokenWithdrawRules;
mapping(address => WithdrawRecord[]) private withdrawRecords;
```

## gas 消耗分析

为于 `ERC20` 转账做对比，这里实现了一个简单的 ERC20 合约：[ERC20Token.sol](./src/ERC20Token.sol)。

利用 `foundry test --gas-report` 估计 gas 消耗情况（后面的倍数均以 ERC20 `transfer` 为基准对比）：

- ERC20 `transfer` 平均 gas : `34461`
- V1 方法 1 `withdraw` 平均 gas : `108534`, 约 3.15 倍
- V1 方法 2 `withdraw` 平均 gas : `105002`, 约 3.05 倍
- V2 `withdraw` 平均 gas : `113006`, 约 3.28 倍

### ERC20 gas report

| src/ERC20Token.sol:ERC20Token contract |                 |       |        |       |         |
| -------------------------------------- | --------------- | ----- | ------ | ----- | ------- |
| Deployment Cost                        | Deployment Size |       |        |       |         |
| 744404                                 | 4188            |       |        |       |         |
| Function Name                          | min             | avg   | median | max   | # calls |
| approve                                | 26183           | 45737 | 46119  | 46227 | 297     |
| balanceOf                              | 519             | 576   | 519    | 2519  | 311     |
| transfer                               | 29370           | 34461 | 34170  | 51282 | 101     |

### V1 方法 1 gas report

| src/AllowanceWallet.sol:AllowanceWallet contract |                 |        |        |        |         |
| ------------------------------------------------ | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost                                  | Deployment Size |        |        |        |         |
| 461052                                           | 2088            |        |        |        |         |
| Function Name                                    | min             | avg    | median | max    | # calls |
| OWNER                                            | 204             | 204    | 204    | 204    | 1       |
| TOKEN_ADDRESS                                    | 182             | 182    | 182    | 182    | 1       |
| deposit                                          | 29158           | 73874  | 74826  | 74934  | 269     |
| withdraw                                         | 21564           | 108534 | 109612 | 143649 | 72      |

### V1 方法 2 gas report

| src/AllowanceWallet.sol:AllowanceWallet contract |                 |        |        |        |         |
| ------------------------------------------------ | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost                                  | Deployment Size |        |        |        |         |
| 558220                                           | 2539            |        |        |        |         |
| Function Name                                    | min             | avg    | median | max    | # calls |
| OWNER                                            | 204             | 204    | 204    | 204    | 1       |
| TOKEN_ADDRESS                                    | 182             | 182    | 182    | 182    | 1       |
| deposit                                          | 29158           | 73878  | 74826  | 74934  | 269     |
| withdraw                                         | 21564           | 105002 | 103692 | 156215 | 72      |

### V2 gas report

| src/AllowanceWalletV2.sol:AllowanceWalletV2 contract |                 |        |        |        |         |
| ---------------------------------------------------- | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost                                      | Deployment Size |        |        |        |         |
| 761044                                               | 3350            |        |        |        |         |
| Function Name                                        | min             | avg    | median | max    | # calls |
| OWNER                                                | 183             | 183    | 183    | 183    | 1       |
| deposit                                              | 29671           | 74203  | 75830  | 75878  | 28      |
| getTokenRule                                         | 1004            | 1004   | 1004   | 1004   | 1       |
| setTokenRule                                         | 24618           | 133972 | 138000 | 138048 | 28      |
| withdraw                                             | 22078           | 113006 | 113702 | 175617 | 68      |

## 单元测试结果

| File                      | % Lines        | % Statements   | % Branches    | % Funcs         |
| ------------------------- | -------------- | -------------- | ------------- | --------------- |
| src/AllowanceWallet.sol   | 97.30% (36/37) | 95.56% (43/45) | 80.00% (8/10) | 100.00% (8/8)   |
| src/AllowanceWalletV2.sol | 97.30% (36/37) | 93.48% (43/46) | 75.00% (9/12) | 100.00% (10/10) |
| src/AllowanceWalletV3.sol | 0.00% (0/43)   | 0.00% (0/56)   | 0.00% (0/12)  | 0.00% (0/11)    |
| src/ERC20Token.sol        | 100.00% (1/1)  | 100.00% (1/1)  | 100.00% (0/0) | 100.00% (1/1)   |

## V3

### 3.1 功能

在 V1 方法 2 的基础上，支持多币种，采用单一提取规则进行限制。如，钱包中同时保存 LINK, wETH, USDT，限制每天提取的各类资产总和不超过 100 U

### 3.2 核心逻辑

通过引入 Chainlink 的聚合器合约，获取币种的价格，并折合成 USDT 价值，判断是否满足提取规则。

```solidity
import {AggregatorV3Interface} from "foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

function getTokenPrice(address token) internal view returns (uint256) {
    AggregatorV3Interface priceContract = AggregatorV3Interface(
        tokenPriceContracts[token]
    );
    (, int256 price, , , ) = priceContract.latestRoundData();
    return uint256(price);
}
```
